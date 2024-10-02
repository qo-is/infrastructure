{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{

  imports = [
    ../base-minimal
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub.enable = true;

  system.autoUpgrade.allowReboot = true;

  services.qemuGuest.enable = true;

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "sr_mod"
  ];

  # Taken from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/minimal.nix
  documentation.enable = lib.mkDefault false;

  documentation.doc.enable = lib.mkDefault false;

  documentation.info.enable = lib.mkDefault false;

  documentation.man.enable = lib.mkDefault false;

  documentation.nixos.enable = lib.mkDefault false;

}
