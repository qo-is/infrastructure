{ config, pkgs, ... }:
{

  imports = [ ./cloud.nix ];

  qois.postgresql.package = pkgs.postgresql_14;
}
