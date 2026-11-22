# Lib

## Overview

Shared Nix helpers for auto-discovering submodules by directory convention. Used throughout the repo (e.g. nixos-modules, nixos-configurations) to import every subdirectory containing a `default.nix`.

## Interface

- `getSubDirs base`: names of direct subdirectories of `base` [default.nix:getSubDirs].
- `isFolderWithFile fileName basePath folderName`: `pathExists` of `basePath/folderName/fileName` [default.nix:isFolderWithFile].
- `foldersWithNix base`: subfolder names that contain `default.nix` [default.nix:foldersWithNix].
- `loadSubmodulesFrom basePath`: list of paths to `<basePath>/<folder>/default.nix` for each such folder [default.nix:loadSubmodulesFrom].

## Invariants

- Only direct children are considered, no recursion; non-directory entries (including symlinks, per `readDir` type) are skipped [default.nix:getSubDirs].
- Only the file name `default.nix` marks a submodule [default.nix:foldersWithNix].

## Side Effects

None. Reads directory listings at evaluation time (`builtins.readDir`, `pathExists`).

## Verification

- Run: `nix flake check`
