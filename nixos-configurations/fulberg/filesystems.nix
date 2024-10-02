{ config, pkgs, ... }:
{

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/360a6bc9-fc4e-4803-bd53-69320ac32ac5";
      fsType = "btrfs";
      options = [
        "defaults"
        "subvol=nixos"
        "noatime"
      ];
    };
    "/mnt/nas" = {
      device = "10.1.1.39:/qois";
      fsType = "nfs";
      options = [
        "defaults"
        "noatime"
        "soft"
      ];
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/73f91e99-d856-4504-b6b2-d60f855d6d95"; } ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}
