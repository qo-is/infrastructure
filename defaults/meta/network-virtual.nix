{
  config,
  lib,
  pkgs,
  ...
}:
{
  qois.meta.network.virtual =
    let
      physical-network = config.qois.meta.network.physical;
    in
    {
      vpn = {
        v4 = {
          id = "100.64.0.0";
          prefixLength = 10;
        };
        domain = "vpn.qo.is";
        hosts = { };
      };

      backplane = {
        v4 = {
          id = "10.250.0.0";
          prefixLength = 24;
        };
        domain = "backplane.net.qo.is";

        hosts = {
          fulberg = {
            v4.ip = "10.250.0.1";
            endpoint = {
              fqdn = physical-network.plessur-ext.hosts.calanda.fqdn;
              port = 51821;
            };
            publicKey = "xcQOu+pp4ckNygcsLmJL1NmUzbbC+k3I7y+hJ9Ul4nk=";
            persistentKeepalive = 25;
          };
          lindberg = {
            v4.ip = "10.250.0.2";
            #endpoint = { # TODO: Port forwarding
            #  fqdn = physical-network.riedbach-ext.hosts.lindberg.fqdn;
            #  port = 51821;
            #};
            publicKey = "uxxdpFXSTnfTvzSEzrUq4DuWSILJD5tNj6ks2jhWF10=";
            persistentKeepalive = 25; # TODO: Remove when port forwarding enabled
          };
          lindberg-nextcloud = {
            v4.ip = "10.250.0.3";
            publicKey = "6XGL4QKB8AMpm/VGcTgWqk9RiSws7DmY5TpIDkXbwlg=";
            persistentKeepalive = 25;
          };
          tierberg = {
            v4.ip = "10.250.0.4";
            publicKey = "51j1l+pT9W61wx4y2KyUb1seLdCHs3FUKAjmrHBFz1w=";
            persistentKeepalive = 25;
          };
          stompert = {
            v4.ip = "10.250.0.5";
            publicKey = "CHTjQbmN9WhbRCxKgowxpMx4c5Zu0NDk0rRXEvuB3XA=";
            persistentKeepalive = 25;
          };
          calanda = {
            v4.ip = "10.250.0.6";
            publicKey = "WMuMCzo8e/aNeGP7256mhK0Fe+x06Ws7a9hOZDPCr0M=";
            endpoint = {
              fqdn = physical-network.plessur-ext.hosts.calanda.fqdn;
              port = 51823;
            };
          };
          lindberg-build = {
            v4.ip = "10.250.0.7";
            publicKey = "eWuvGpNVl601VDIgshOm287dlZa/5gF9lL4SjYEbIG8=";
            persistentKeepalive = 25;
          };
          lindberg-webapps = {
            v4.ip = "10.250.0.8";
            publicKey = "LOA3Kumg8FV4DJxONwv+/8l/jOQLJ6SD2k/RegerR04=";
            persistentKeepalive = 25;
          };
          cyprianspitz = {
            v4.ip = "10.250.0.9";
            endpoint = {
              fqdn = physical-network.plessur-ext.hosts.calanda.fqdn;
              port = 51824;
            };
            publicKey = "iLzHSgIwZz44AF7961mwEbK9AnSwcr+aKpd7XAAVTHo=";
          };
        };
      };

      lindberg-vms-nat = {
        v4 = {
          id = "10.247.0.0";
          prefixLength = 24;
        };
        domain = "lindberg-vms-nat.net.qo.is";
        hosts = {
          lindberg.v4.ip = "10.247.0.1";
        };
      };

      cyprianspitz-vms-nat = {
        v4 = {
          id = "10.247.0.0";
          prefixLength = 24;
        };
        domain = "cyprianspitz-vms-nat.net.qo.is";
        hosts = {
          cyprianspitz.v4.ip = "10.248.0.1";
        };
      };
    };
}
