{
  description = "Incus NixOS container for Podman";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
            sandbox = false;
          };

          virtualisation.podman.enable = true;
          virtualisation.podman.dockerCompat = true;
        }
        {
          # Add a new user "styx"
          users.users.styx = {
            isNormalUser = true; # marks as a normal user
            description = "styx"; # optional
            hashedPassword = "$y$j9T$0d6Gx30pnve.klhKgmZwe0$JrdRjFcObsc59RL/ug5fu0DQDdCwKnSOb.b8KIYw2G5"; # password
            uid = 2000; # set user id
            extraGroups = [ "wheel" ]; # sudo access
          };
          # Add a new user "tartarus"
          users.users.tartarus = {
            isNormalUser = true; # marks as a normal user
            description = "tartarus"; # optional
            hashedPassword = "$y$j9T$zPyT0FHrHcnf93tR6oupe/$XP2h7uePCAF8Z6U6xb9eTFDIf5Va9G1tVrOnuwSmIb0"; # password
            uid = 4000; # set user id
            extraGroups = [ "podman" ]; # podman access
          };
        }
      ];
    };
  };
}
