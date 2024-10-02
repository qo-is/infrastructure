{ pkgs, ... }:
{
  disko.devices = {
    disk = rec {
      data-1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST18000NM003D-3DL103_ZVTAA02H";
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
      data-2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST18000NM003D-3DL103_ZVTAEYPL";
        content = data-1.content;
      };
      backup = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K5ZUA0VR";
        content = {
          type = "gpt";
          partitions = {
            backup = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted_backup";
                settings.allowDiscards = true;
                askPassword = true;
                content = {
                  type = "filesystem";
                  format = "btrfs";
                  mountpoint = "/mnt/backup";
                  mountOptions = [
                    "defaults"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
      system-1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL22T0HBLB-00B00_S677NE0NC01017";
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
        device = "/dev/disk/by-id/nvme-Lexar_SSD_NM790_2TB_NLK644R000627P2202";
        content = pkgs.lib.recursiveUpdate system-1.content {
          partitions.boot.content.mountpoint = "/boot-secondary";
        };
      };
      cache = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S12PNEAD274438F";
        content = {
          type = "gpt";
          partitions = {
            crypted_cache = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted_cache";
                settings.allowDiscards = true;
                askPassword = true;
                content = {
                  type = "lvm_pv";
                  vg = "vg_cache";
                };
              };
            };
          };
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
          settings = {
            allowDiscards = true;
            bypassWorkqueues = true;
          };
          askPassword = true;
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
          settings.allowDiscards = true;
          askPassword = true;
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
            size = "12TB";
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
          hv_lindberg = {
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
      vg_cache = {
        type = "lvm_vg";
        lvs = {
          lv_swap_lindberg = {
            size = "10GiB";
            content = {
              type = "swap";
            };
          };
        };
      };
    };
  };
}
