{
  self,
  pkgs,
  nixpkgs-nixos-stable,
  disko,
  sops-nix,
  ...
}@inputs:
let
  inherit (pkgs.lib) genAttrs;
  inherit (nixpkgs-nixos-stable.lib) nixosSystem;
  configs = self.lib.foldersWithNix ./.;
in
genAttrs configs (
  config:
  nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
    };
    modules = [
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
      self.nixosModules.default
      ./${config}/default.nix
      ./secrets.nix
    ];
  }
)
