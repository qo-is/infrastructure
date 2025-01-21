{
  config,
  pkgs,
  lib,
  ...
}:
{

  imports = [
    ./nixpkgs-cache.nix
  ];

  qois.git-ci-runner.enable = true;
  qois.attic.enable = true;
  qois.postgresql.package = pkgs.postgresql_15;
  qois.renovate.enable = true;

  # Remove substituters that are hosted on this node, to prevent lockups
  #  since the current nix implementation is not forgiving with unavailable subsituters.
  # The qois-infrastructure cache is not needed,
  #  since the builds are done (and cached) on this host anyway.
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org?priority=40"
  ];
}
