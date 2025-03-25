{
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "xhci_pci"
    "ahci"
    "virtio-pci"
    "igb"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  hardware.cpu.amd.updateMicrocode = true;
  nix.settings.max-jobs = lib.mkDefault 24;
}
