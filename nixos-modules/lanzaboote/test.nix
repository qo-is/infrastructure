{ lib, ... }:
{
  nodes.machine = {
    virtualisation.useEFIBoot = true;
    virtualisation.tpm.enable = true; # swtpm, needed for measured boot / pcrlock
    system.switch.enable = true;

    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.timeout = lib.mkForce 0;

    # Stand-in for the second ESP; doesn't need to be a real partition since
    # the install step just needs a writable mount point to copy signed
    # artifacts into (matches how upstream's own extra-efi-partitions test
    # exercises this - /boot2 there also isn't a dedicated partition).
    fileSystems."/boot2" = {
      device = "none";
      fsType = "tmpfs";
    };

    qois.lanzaboote = {
      enable = true;
      extraEfiSysMountPoints = [ "/boot2" ];
    };
  };
}
