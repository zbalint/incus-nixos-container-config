{ modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
    /etc/nixos/incus.nix
  ];

  networking = {
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;

    firewall.allowedUDPPorts = [ 41641 ];
  };

  systemd.network = {
    enable = true;
    networks."50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  nix.settings.sandbox = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.05";

  services.tailscale = {
    enable = true;
    # authKey = "YOUR_TAILSCALE_AUTH_KEY_HERE";
  };

  # --- Custom systemd service + timer ---
  systemd.services.system-updater = {
    description = "Download and execute remote shell script";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/zbalint/incus-nixos-container-config/refs/heads/master/system-upgrade.sh | ${pkgs.bash}/bin/bash";
    };
  };

  systemd.timers.system-updater = {
    description = "Run remote script every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
