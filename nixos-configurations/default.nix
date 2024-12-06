{
  self,
  pkgs,
  nixpkgs-nixos-stable,
  disko,
  sops-nix,
  ...
}@inputs:
let
  configs = self.lib.foldersWithNix ./.;
in
pkgs.lib.genAttrs configs (
  config:
  nixpkgs-nixos-stable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
    };
    modules = [
      self.nixosModules.default
      ./${config}/default.nix
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
      (
        { ... }:
        {
          system.extraSystemBuilderCmds = "ln -s ${self} $out/nixos-configuration";
          imports = [ ./secrets.nix ];
        }
      )
    ];
  }
)
