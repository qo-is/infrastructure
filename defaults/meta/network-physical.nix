{
  ...
}:
{
  qois.meta.network.physical = {
    plessur-ext = {
      v4 = {
        id = "85.195.200.253";
        prefixLength = 24;
      };
      v6 = {
        id = "2a02:169:1e02::";
        prefixLength = 48;
      };
      domain = "plessur-ext.net.qo.is";
      hosts = {
        calanda = {
          v4.ip = "85.195.200.253";
        };
      };
    };

    plessur-dmz = {
      v4 = {
        id = "10.1.2.0";
        prefixLength = 24;
        gateway = "10.1.2.1";
        nameservers = [ "10.1.2.1" ];
      };
      domain = "plessur-dmz.net.qo.is";

      hosts = {
        calanda = {
          v4.ip = "10.1.2.1";
        };
      };
    };

    plessur-lan = {
      v4 = {
        id = "10.1.1.0";
        prefixLength = 24;
        # Note: DHCP from .2 to .249, see calanda config
      };
      domain = "plessur-lan.net.qo.is";

      hosts = {
        calanda = {
          v4.ip = "10.1.1.1";
        };
        cyprianspitz.v4.ip = "10.1.1.250";
      };
    };

    riedbach-ext = {
      # IP: Dynamic
      domain = "riedbach-ext.net.qo.is";

      hosts = {
        lindberg = {
          # TODO: This is the router, not really lindberg.
          v4.ip = "145.40.194.243";
        };
      };
    };

  };
}
