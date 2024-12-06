{ config, pkgs, ... }:

{
  imports = [
    ./networking.nix
    ./filesystems.nix
    ./backup.nix

    ../../defaults/hardware/apu1.nix
    # wle600: Not used currently

    ../../defaults/base
    ../../defaults/meta
  ];

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.11"; # Did you read the comment?
}
