{
  config,
  lib,
  ...
}:
let
  cfg = config.qois.system.virtual-machine;
in
with lib;
{
  options.qois.system.virtual-machine.enable =
    mkEnableOption "Enable qois system vm default configuration";

  config = lib.mkIf cfg.enable {

    boot.loader.grub.enable = true;

    system.autoUpgrade.allowReboot = true;

    services.qemuGuest.enable = true;

    boot.initrd.availableKernelModules =
      [
        "ahci"
        "xhci_pci"
        "sr_mod"
      ]
      ++
      # Taken from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/qemu-guest.nix
      [
        "virtio_net"
        "virtio_pci"
        "virtio_mmio"
        "virtio_blk"
        "virtio_scsi"
        "9p"
        "9pnet_virtio"
      ];
    boot.initrd.kernelModules = [
      "virtio_balloon"
      "virtio_console"
      "virtio_rng"
      "virtio_gpu"
    ];

    # Taken from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/minimal.nix
    documentation.enable = lib.mkDefault false;

    documentation.doc.enable = lib.mkDefault false;

    documentation.info.enable = lib.mkDefault false;

    documentation.man.enable = lib.mkDefault false;

    documentation.nixos.enable = lib.mkDefault false;

  };
}
