{ ... }:
{

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/16efc5db-0697-4f39-b64b-fc18ac318625";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=nixos"
      "noatime"
    ];
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/b5104a7c-4a4a-4048-a9f8-44ddb0082632"; } ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}
