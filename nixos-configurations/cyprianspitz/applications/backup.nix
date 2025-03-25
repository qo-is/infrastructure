{ config, ... }:

{
  qois.backup-server = {
    enable = true;
    backupStorageRoot =
      let
        dataDrive = config.disko.devices.lvm_vg.vg_data.lvs.lv_data.content.mountpoint;
      in
      dataDrive + "/backup";
  };
}
