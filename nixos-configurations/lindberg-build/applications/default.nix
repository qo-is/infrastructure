{ config, pkgs, ... }:
{

  imports = [
    ./gitlab-runner.nix
    ./attic.nix
    ./nixpkgs-cache.nix
  ];

  qois.git-ci-runner.enable = true;
}
