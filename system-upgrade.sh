#!/bin/bash

# unreachable from the internet
readonly GOTIFY_TOKEN="A2bEcglYh475ZK."
readonly CONFIG_REPO_URL="https://github.com/zbalint/incus-nixos-container-config.git"
readonly CONFIG_REPO_DIR="/etc/nixos"

CONTAINER_NAME="$(cat /etc/hostname)"
COMMIT_HASH=""

function is_dir_exists() {
    local dir="$1"

    if [ -d "${dir}" ]; then
        return 0
    fi

    return 1
}

function wait_random_delay() {
    # Random delay up to 30 minutes (1800 seconds)
    local delay
    # delay=$(( RANDOM % 1800 ))
    # 10 sec delay during testing
    delay=$(( RANDOM % 10 ))
    echo "Waiting ${delay} seconds before rebuild..."
    sleep ${delay}
}

function gotify_send_notification() {
    local priority="$1"
    local title="$2"
    local message="$3"

    curl -X POST "https://gotify.lab.escapethelan.com/message?token=${GOTIFY_TOKEN}" \
     -F "title=${title}" \
     -F "message=${message}" \
     -F "priority=${priority}"
}

function send_info_notification() {
    local title="$1"
    local message="$2"
    gotify_send_notification 1 "${title}" "${message}"
}

function send_warn_notification() {
    local title="$1"
    local message="$2"
    gotify_send_notification 5 "${title}" "${message}"
}

function send_error_notification() {
    local title="$1"
    local message="$2"
    gotify_send_notification 10 "${title}" "${message}"
}

function git_clone_nixos_config_repo() {
    git clone -b master ${CONFIG_REPO_URL} ${CONFIG_REPO_DIR} || \
    git clone ${CONFIG_REPO_URL} ${CONFIG_REPO_DIR}/temp && \
    mv ${CONFIG_REPO_DIR}/temp/.git ${CONFIG_REPO_DIR}/.git && \
    rm -rf ${CONFIG_REPO_DIR}/temp && \
    cd ${CONFIG_REPO_DIR} && \
    cp incus.nix /tmp && \
    git checkout . && \
    git reset --hard && \
    git clean -df && \
    mv /tmp/incus.nix .
}

function git_fetch_nixos_config_repo() {
    cd /etc/nixos && \
    git fetch origin master
}

function git_check_for_new_commit() {
    local git_local_head
    local git_remote_head

    cd /etc/nixos || return 1

    git_local_head=$(git rev-parse HEAD)
    git_remote_head=$(git rev-parse origin/master)

    if [ "${git_local_head}" != "${git_remote_head}" ]; then
        COMMIT_HASH="${git_remote_head}"
        return 0
    else 
        COMMIT_HASH="${git_local_head}"
        return 1
    fi

    return 1
}

function git_reset_to_origin() {
    git reset --hard origin/master
}

function nixos_update_config() {
    if is_dir_exists "${CONFIG_REPO_DIR}/.git"; then
        echo "Fetching updates from repository..."
        if git_fetch_nixos_config_repo; then
            return 0
        else
            echo "Error: Could not fetch config repository!"
            return 1
        fi
    else
        echo "Cloning config repository..."
        if git_clone_nixos_config_repo; then
            return 0
        else
            echo "Error: Could not clone config repository"
            return 1
        fi
    fi

    return 1
}

function is_rebuild_needed() {
    if nixos_update_config; then
        if git_check_for_new_commit; then
            git_reset_to_origin
            echo "New commits found. Rebuild needed!"
            return 0
        else 
            echo "No new commits."
            return 1
        fi
    fi

    return 1
}

function nixos_rebuild() {
    wait_random_delay && \
    nixos-rebuild build --flake /etc/nixos#container --option sandbox false
}

function nixos_switch() {
    nixos-rebuild switch --flake /etc/nixos#container --option sandbox false
}

function nixos_rollback() {
    nixos-rebuild switch --rollback
}

function check_system_health() {
    # Network
    echo "Check network connectivity..."
    if ! ping -q -c 2 1.1.1.1 >/dev/null 2>&1; then
        echo "Error: Internet is unreachable!"
        return 1
    fi

    return 0
}

function main() {
    if is_rebuild_needed; then
        if nixos_rebuild; then
            if nixos_switch; then
                if check_system_health; then
                    echo "Update was successful!"
                    send_warn_notification \
                        "NixOS Container Update" \
                        "Container $CONTAINER_NAME update finished. Commit: $COMMIT_HASH"
                    return 0
                else
                    echo "System healthcheck failed! Rolling back to previous state..."
                    if nixos_rollback; then
                        echo "Rollback was successful!"
                        send_warn_notification \
                            "NixOS Container Rollback" \
                            "Container $CONTAINER_NAME rollback due to failed post-switch checks. Commit: $COMMIT_HASH"
                        return 0
                    else
                        echo "Rollback failed! Catastrophic failure!"
                        send_error_notification \
                            "NixOS Container Rollback Failed" \
                            "Container $CONTAINER_NAME rollback failed. Commit: $COMMIT_HASH"
                        return 1
                    fi
                fi
            else
                echo "Switch failed! Rolling back to previous state..."
                if nixos_rollback; then
                    echo "Rollback was successful!"
                    send_warn_notification \
                        "NixOS Container Rollback" \
                        "Container $CONTAINER_NAME rollback due to failed post-switch checks. Commit: $COMMIT_HASH"
                    return 0
                else
                    echo "Rollback failed! Catastrophic failure!"
                    send_error_notification \
                        "NixOS Container Rollback Failed" \
                        "Container $CONTAINER_NAME rollback failed. Commit: $COMMIT_HASH"
                    return 1
                fi
            fi
        else
            echo "Rebuild failed!"
            send_error_notification \
                "NixOS Container Rebuild" \
                "Container $CONTAINER_NAME rebuild failed. Commit: $COMMIT_HASH"
            return 1
        fi
    else
        echo "System is already up to date!"
        return 0
    fi
    return 0
}

main