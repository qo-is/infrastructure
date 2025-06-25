{
  self,
  pkgs,
  nixpkgs,
  ...
}@inputs:
let
  inherit (pkgs.lib) genAttrs;
  inherit (nixpkgs.lib) nixosSystem;
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
      self.nixosModules.default
      ./${config}/default.nix
    ];
  }
)
