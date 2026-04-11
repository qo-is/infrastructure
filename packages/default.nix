{
  self,
  flakeSelfSpecialUsage,
  system,
  private,
  pkgs,
  ...
}:
let
  inherit (self.lib) foldersWithNix;
  inherit (pkgs.lib)
    path
    genAttrs
    ;
in
{
  ${system} = genAttrs (foldersWithNix ./.) (
    name:
    pkgs.callPackage (path.append ./. "./${name}/default.nix") {
      inherit
        self
        flakeSelfSpecialUsage
        system
        private
        ;
    }
  );
}
