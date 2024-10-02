{ pkgs, ... }:
let
  lib = pkgs.lib;
  foldersWithNix =
    path:
    let
      folders = lib.attrNames (lib.filterAttrs (n: t: t == "directory") (builtins.readDir path));
      isFolderWithDefaultNix = folder: lib.pathExists (lib.path.append path "./${folder}/default.nix");
    in
    lib.filter isFolderWithDefaultNix folders;

in
{
  inherit foldersWithNix;

  loadSubmodulesFrom =
    path: map (folder: lib.path.append path "./${folder}/default.nix") (foldersWithNix path);
}
