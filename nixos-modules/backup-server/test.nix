{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  nodes.server =
    { ... }:
    {
      qois.backup-server = {
        enable = true;
        backupStorageRoot = "/mnt/data/backup";
      };
      qois.telegraf.enable = mkForce true;

      boot.supportedFilesystems.btrfs = true;
      virtualisation.emptyDiskImages = [ 512 ];
    };
}
