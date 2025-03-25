# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "e1000e"
    "virtio-pci"
  ];
  boot.initrd.kernelModules = [ ];
  #  boot.kernelModules = [ "kvm-intel" "virtio" "tun" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  #  boot.kernelParams = [ "console=ttyS0,115200n8" ];

  hardware.cpu.intel.updateMicrocode = true;
  powerManagement.cpuFreqGovernor = "ondemand";
  nix.settings.max-jobs = lib.mkDefault 8;
}
