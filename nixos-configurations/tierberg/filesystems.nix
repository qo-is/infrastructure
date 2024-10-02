{ config, pkgs, ... }:
{

  boot.initrd.luks.devices = {
    "system".device = "/dev/disk/by-uuid/ac7f7ef2-280d-4b9f-8150-a6f11ecec1df";
    "swap".device = "/dev/disk/by-uuid/6ce21585-6813-46d0-9a98-ebcfa507bdb0";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/c775e380-b15f-499b-94f2-8caa27e6e0ff";
      fsType = "btrfs";
      options = [
        "defaults"
        "subvol=nixos"
        "noatime"
      ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/0b22a6bc-0721-49d6-9e66-1f8d9258f47b";
      fsType = "ext4";
    };
    "/mnt/nas-backup-qois" = {
      device = "192.168.254.1:/raid0/data/_NAS_NFS_Exports_/backup-qois";
      fsType = "nfs";
      options = [
        "defaults"
        "noatime"
        "soft"
        "vers=3"
      ];
    };
    "/mnt/nas-backup-coredump" = {
      device = "192.168.254.1:/raid0/data/_NAS_NFS_Exports_/backup-qois";
      fsType = "nfs";
      options = [
        "defaults"
        "noatime"
        "soft"
        "vers=3"
      ];
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/e91f9aba-1e59-4d41-a772-f11d4314dc19"; } ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}
