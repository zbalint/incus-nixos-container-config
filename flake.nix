{
  description = "Incus NixOS container for Docker";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./incus.nix
        {
          nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
            sandbox = false;
          };

          # Enable Docker instead of Podman
          virtualisation.docker.enable = true;

          # Optionally enable rootless Docker
          # virtualisation.docker.rootless.enable = true;

          # Install packages system-wide
          environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
            git
          ];
        }
        {
          # Add a new user "styx"
          users.users.styx = {
            isNormalUser = true;
            description = "styx";
            hashedPassword = "$y$j9T$0d6Gx30pnve.klhKgmZwe0$JrdRjFcObsc59RL/ug5fu0DQDdCwKnSOb.b8KIYw2G5";
            uid = 2000;
            extraGroups = [ "wheel" "docker" ]; # allow Docker usage
          };
          # Add a new user "tartarus"
          users.users.tartarus = {
            isNormalUser = true;
            description = "tartarus";
            hashedPassword = "$y$j9T$zPyT0FHrHcnf93tR6oupe/$XP2h7uePCAF8Z6U6xb9eTFDIf5Va9G1tVrOnuwSmIb0";
            linger = true;
            uid = 4000;
            extraGroups = [ "docker" ]; # allow Docker usage
          };
        }
      ];
    };
  };
  extraFiles = [ "incus.nix" ];
}
