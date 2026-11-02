{ config, ... }:

let
  dataVolume = config.disko.devices.lvm_vg.vg_data.lvs.lv_data.content;
in
{
  qois.backup-server = {
    enable = true;
    backupStorageRoot = dataVolume.mountpoint + dataVolume.subvolumes."/backup".name;
  };
}
