{ ... }:
{
  boot.isContainer = true;

  networking.hostName = "lindberg-jellyfin";
  networking.useDHCP = false;
  networking.nameservers = [ "10.246.0.1" ];

  qois.jellyfin.enable = true;
  qois.jellyfin.domain = "media.qo.is";

  # Disable host-level services that don't belong in this container;
  # backups, mail, and monitoring are handled by the lindberg host.
  qois.backup-client.enable = false;
  qois.outgoing-server-mail.enable = false;
  qois.telegraf.enable = false;

  system.stateVersion = "25.11";
}
