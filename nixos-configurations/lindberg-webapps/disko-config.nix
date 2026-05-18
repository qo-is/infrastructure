{ ... }:
{
  disko.devices.disk = {
    system = {
      type = "disk";
      device = "/dev/vda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            # for grub MBR
            size = "1M";
            type = "EF02";
          };
          system = {
            size = "100%";
            content = {
              type = "btrfs";
              subvolumes = {
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [ "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
