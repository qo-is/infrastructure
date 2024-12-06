{ config, pkgs, ... }:
{

  imports = [
    ./attic.nix
    ./nixpkgs-cache.nix
  ];

  qois.git-ci-runner.enable = true;
  qois.postgresql.package = pkgs.postgresql_15;
}
