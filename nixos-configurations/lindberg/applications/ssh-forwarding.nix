{ pkgs, ... }:
{
  # Allow login to use this host as jumphost.
  users.groups.tunnel = { };
  users.users.tunnel = {
    group = "tunnel";
    isSystemUser = true;
    shell = "${pkgs.shadow}/bin/nologin";
    createHome = false;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKFz08hZLeQtnaqWKZLS1NrPirEKOVWoFipOdbfBANJ/ saba@sabaworkstation"
    ];
  };
}
