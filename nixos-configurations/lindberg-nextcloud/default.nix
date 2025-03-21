{ config, pkgs, ... }:

{
  imports = [
    ../../defaults/meta
    ./applications
    ./backup.nix
    ./secrets.nix
  ];

  qois.system.virtual-machine.enable = true;

  boot.loader.grub.device = "/dev/vda";
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5b6823ec-921f-400a-a7c0-3fe34d56ae12";
    fsType = "btrfs";
    options = [ "subvol=root" ];
  };

  systemd.mounts = [
    {
      what = "data/nextcloud";
      where = "/var/lib/nextcloud";
      type = "virtiofs";
      wantedBy = [ "multi-user.target" ];
      enable = true;
    }
  ];

  networking.hostName = config.qois.meta.hosts.lindberg-nextcloud.hostName;
  networking.useDHCP = false;
  networking.interfaces.enp2s0.useDHCP = true;

  qois.backplane-net.enable = true;

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
