{ config, pkgs, ... }:

{
  imports = [
    ./networking.nix
    ./filesystems.nix

    ../../defaults/hardware/apu.nix

    ../../defaults/meta
  ];

  qois.system.physical.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like fi:le locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
