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
    nixpkgs_cache = {
      type = "disk";
      device = "/dev/vdb";
      content = {
        type = "gpt";
        partitions.nixpkgs_cache = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/var/cache/nginx/nixpkgs-cache";
          };
        };
      };
    };
    swap = {
      type = "disk";
      device = "/dev/vdc";
      content = {
        type = "gpt";
        partitions.swap = {
          size = "100%";
          content.type = "swap";
        };
      };
    };
  };
}
