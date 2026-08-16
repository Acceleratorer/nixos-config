{
  description = "accelra's NixOS configuration";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6282.2f5a153c270b/nixexprs.tar.xz";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-dots = {
      url = "github:caelestia-dots/caelestia/a6ed1e5e831aba9aac46265ae156db4fab2b9e43";
      flake = false;
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell/817a220e8e87c4df9f3681033a0d8a8054cdaa30";
      inputs.caelestia-cli.url = "github:caelestia-dots/cli/751fbc555a83faba5dd589270d14eeb22afab174";
      inputs.caelestia-cli.inputs.caelestia-shell.follows = "caelestia-shell";
      inputs.caelestia-cli.inputs.nixpkgs.follows = "caelestia-shell/nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=28771c7c74b42e20afca0b1b63980cb46515537c";
      inputs.quickshell.inputs.nixpkgs.follows = "caelestia-shell/nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, caelestia-dots, caelestia-shell, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkNixos = {
        desktopProfile ? "classic",
      }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit desktopProfile; };
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit caelestia-dots caelestia-shell desktopProfile;
                };
                useGlobalPkgs = true;
                users.accelra = import ./home.nix;
              };

              system.nixos.revision = "2f5a153c270b70cb0f8c11f46d96d6d3bc39f4e3";
              system.nixos.versionSuffix = ".6282.2f5a153c270b";
            }
          ];
        };
    in {
    packages.${system} = {
      caelestia-shell-cryoforge =
        pkgs.callPackage ./packages/caelestia-cryoforge.nix {
          inherit caelestia-shell;
        };
      hyprexpo = pkgs.callPackage ./packages/hyprexpo.nix { };
    };

    nixosConfigurations.nixos = mkNixos { };

    nixosConfigurations.nixos-caelestia-stock = mkNixos {
      desktopProfile = "caelestia-stock";
    };

    nixosConfigurations.nixos-caelestia-cryoforge = mkNixos {
      desktopProfile = "caelestia-cryoforge";
    };
  };
}
