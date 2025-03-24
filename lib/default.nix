{ pkgs, ... }:
let
  inherit (pkgs.lib)
    attrNames
    filterAttrs
    filter
    pathExists
    path
    ;
  # Get a list of all subdirectories of a directory.
  getSubDirs = base: attrNames (filterAttrs (n: t: t == "directory") (builtins.readDir base));
  # Check if a folder with a base path and folder name contains a file with a specific name
  isFolderWithFile =
    fileName: basePath: folderName:
    (pathExists (path.append basePath "./${folderName}/${fileName}"));
  # Get a list of subfolders that contain a default.nix file.
  foldersWithNix = base: filter (isFolderWithFile "default.nix" base) (getSubDirs base);

in
{
  inherit getSubDirs isFolderWithFile foldersWithNix;

  # Get a list of default.nix files that are nix submodules of the current folder.
  loadSubmodulesFrom =
    basePath: map (folder: path.append basePath "./${folder}/default.nix") (foldersWithNix basePath);
}
