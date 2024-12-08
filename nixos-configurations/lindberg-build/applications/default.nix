{
  config,
  pkgs,
  lib,
  ...
}:
{

  imports = [
    ./attic.nix
    ./nixpkgs-cache.nix
  ];

  qois.git-ci-runner.enable = true;
  qois.postgresql.package = pkgs.postgresql_15;

  # Remove substituters that are hosted on this node, to prevent lockups.
  # The qois-infrastructure cache is not needed,
  #  since the builds are done (and cached) on this host anyway.
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org?priority=40"
  ];
}
