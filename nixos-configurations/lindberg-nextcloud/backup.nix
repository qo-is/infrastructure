{ config, pkgs, ... }:

{

  qois.backup-client.excludePaths = [
    "/var/lib/nextcloud/data" # Data is backed up on lindberg
  ];
}
