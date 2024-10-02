# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ../../defaults/backplane-net
    ../../defaults/hardware/apu.nix
    ../../defaults/base
    ../../defaults/meta
  ];

  boot.initrd.luks.devices."systems".device = "/dev/disk/by-uuid/5718bd19-cb7a-4728-9ec4-6b2be48215fc";

  fileSystems."/" = {
    device = "/dev/mapper/vg_systems-hv_stompert";
    fsType = "btrfs";
    options = [ "subvol=root" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/bbe12368-1f81-4924-a12c-2edec886f7c8";
    fsType = "ext4";
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/851e1d05-569f-41ca-8ed9-d7ffba489ffe"; } ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  services.qois.luks-ssh = {
    enable = true;
    interface = "eth1";
    sshPort = 2222;
  };

  networking.hostName = "stompert"; # Define your hostname.

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.enp2s0.useDHCP = true;
  networking.interfaces.enp3s0.useDHCP = true;
  networking.tempAddresses = "disabled";

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "22.11"; # Did you read the comment?
}
