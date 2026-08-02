{
  description = "accelra's NixOS configuration";

  inputs.nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6282.2f5a153c270b/nixexprs.tar.xz";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          system.nixos.revision = "2f5a153c270b70cb0f8c11f46d96d6d3bc39f4e3";
          system.nixos.versionSuffix = ".6282.2f5a153c270b";
        }
      ];
    };
  };
}
