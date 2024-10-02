{ pkgs, ... }:
{
  disko.devices = {
    disk = rec {
      data-1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST16000NM000J-2TW103_ZRS110XA";
        content = {
          type = "gpt";
          partitions = {
            raid_data = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid_data";
              };
            };
          };
        };
      };
      #data-2 = { # TODO
      #  type = "disk";
      #  device = "/dev/disk/by-id/ata-TODO";
      #  content = data-1.content;
      #};
      system-1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Lexar_SSD_NM790_1TB_NL8052R000144P2202";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot-primary";
              };
            };
            raid_system = {
              start = "5G";
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid_system";
              };
            };
          };
        };
      };
      system-2 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Lexar_SSD_NM790_1TB_NL8052R002402P2202";
        content = pkgs.lib.recursiveUpdate system-1.content {
          partitions.boot.content.mountpoint = "/boot-secondary";
        };
      };
    };

    mdadm = {
      "raid_system" = {
        type = "mdadm";
        level = 1;
        content = {
          type = "luks";
          name = "crypted_system";
          passwordFile = "/run/secrets/system/hdd.key";
          settings = {
            allowDiscards = true;
            bypassWorkqueues = true;
          };
          content = {
            type = "lvm_pv";
            vg = "vg_system";
          };
        };
      };
      "raid_data" = {
        type = "mdadm";
        level = 1;
        content = {
          type = "luks";
          name = "crypted_data";
          passwordFile = "/run/secrets/system/hdd.key";
          settings.allowDiscards = true;
          content = {
            type = "lvm_pv";
            vg = "vg_data";
          };
        };
      };
    };
    lvm_vg = {
      vg_data = {
        type = "lvm_vg";
        lvs = {
          lv_data = {
            size = "14TB";
            content = {
              type = "filesystem";
              format = "btrfs";
              mountpoint = "/mnt/data";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };
        };
      };
      vg_system = {
        type = "lvm_vg";
        lvs = {
          hv_cyprianspitz = {
            size = "100GiB";
            content = {
              type = "btrfs";
              mountOptions = [
                "defaults"
                "noatime"
              ];
              subvolumes = {
                "/root".mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
