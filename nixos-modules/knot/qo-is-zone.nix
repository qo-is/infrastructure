{ config, lib, ... }:

let
  inherit (lib)
    attrValues
    concatMap
    filter
    hasSuffix
    mapAttrsToList
    optional
    ;

  domain = "qo.is";
  webapps = "lindberg.riedbach-ext.net.qo.is.";
  primaryNameserverAddress = "85.195.200.253";

  networks =
    attrValues config.qois.meta.network.physical ++ attrValues config.qois.meta.network.virtual;

  metaRecords = concatMap (
    network:
    concatMap
      (
        { fqdn, host }:
        [
          {
            name = "${fqdn}.";
            type = "A";
            data = host.v4.ip;
          }
        ]
        ++ optional (host.v6 != null) {
          name = "${fqdn}.";
          type = "AAAA";
          data = host.v6.ip;
        }
      )
      (
        filter (entry: hasSuffix ".${domain}" entry.fqdn) (
          mapAttrsToList (_name: host: {
            inherit host;
            inherit (host) fqdn;
          }) network.hosts
        )
      )
  ) networks;

  # Hosts that are not (yet) described in defaults/meta.
  foreignHostRecords =
    mapAttrsToList
      (name: data: {
        inherit name data;
        type = "A";
      })
      {
        "stompert.backplane.net.qo.is." = "10.250.0.5";
        "stompert.eem-ext.net.qo.is." = "81.204.174.111";
        "router.lattenbach-ext.net.qo.is." = "5.226.148.126";
        "calanda.plessur.net.qo.is." = "85.195.200.253";
      };

  serviceAliases =
    map
      (name: {
        name = "${name}.${domain}.";
        type = "CNAME";
        data = webapps;
      })
      [
        "attic"
        "cloud"
        "docs-ops"
        "git"
        "id"
        "jellyfin.media"
        "media"
        "monitoring"
        "nixpkgs-cache"
        "vault"
        "www"
      ];
in
{
  qois.knot.zones.${domain} = {
    dnssec = true;

    soa = {
      primaryNameserver = "ns1.${domain}.";
      hostmaster = "hostmaster.${domain}.";
    };

    secondaries = {
      ch-inter-ch.address = "80.74.136.136";
      ch-inter-de.address = "78.46.32.78";
      ch-inter-nl.address = "62.212.66.135";
    };

    records =
      metaRecords
      ++ foreignHostRecords
      ++ serviceAliases
      ++ [
        {
          name = "${domain}.";
          type = "NS";
          data = "ns1.${domain}.";
        }
        {
          name = "${domain}.";
          type = "NS";
          data = "ch.ch-inter.net.";
        }
        {
          name = "${domain}.";
          type = "NS";
          data = "de.ch-inter.net.";
        }
        {
          name = "${domain}.";
          type = "NS";
          data = "nl.ch-inter.net.";
        }
        {
          name = "ns1.${domain}.";
          type = "A";
          data = primaryNameserverAddress;
        }

        {
          name = "${domain}.";
          type = "A";
          data = "145.40.194.243";
        }
        {
          name = "${domain}.";
          type = "MX";
          data = "0 mx.${domain}.";
        }
        {
          name = "mx.${domain}.";
          type = "A";
          data = "149.126.4.120";
        }
        {
          name = "mx.${domain}.";
          type = "AAAA";
          data = "2a01:ab20:0000:0004:0000:0000:0000:0120";
        }
        {
          name = "stompert.eem-ext.net.${domain}.";
          type = "AAAA";
          data = "2a02:a449:0047:0001:020d:b9ff:fe4a:7a49";
        }

        {
          name = "vpn.${domain}.";
          type = "CNAME";
          data = "calanda.plessur-ext.net.${domain}.";
        }
        {
          name = "*.vpn.${domain}.";
          type = "CNAME";
          data = "vpn.${domain}.";
        }
        {
          name = "*.vpn.net.${domain}.";
          type = "CNAME";
          data = "vpn.${domain}.";
        }
        {
          name = "autoconfig.${domain}.";
          type = "CNAME";
          data = "maildiscovery.cyon.ch.";
        }
        {
          name = "openpgpkey.${domain}.";
          type = "CNAME";
          data = "wkd.keys.openpgp.org.";
        }
        {
          name = "_autodiscover._tcp.${domain}.";
          type = "SRV";
          ttl = 3600;
          data = "0 0 443 maildiscovery.cyon.ch.";
        }

        {
          name = "${domain}.";
          type = "TXT";
          data = "v=spf1 include:spf.protection.cyon.net -all";
        }
        {
          name = "default._domainkey.${domain}.";
          type = "TXT";
          data = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvqdVBBTioPZafUcajXYogvOb76Dnnu7K3PQtjafKpM4Am40L17K5I1UjTnuxoaUTQYVQiAKWnI3LoaYPUTWBDxYITv2oiyr/RtBkmetMyGrk/Fvew9Ankp9T5H4gASZqUqg/AWKXTsrxL5AqfULAlfkdOidwxrxMoH7IOWmfkNCb/sPUbnEq3HqKoOpoBduVHLCO4sDj10zbYsK3X+2Ju+k1ANiMfrB6GWJ1zmVwEGE34q1ztbX9cWbkpu1JgvLXde9gFNW9b95egHPgaqwPYOwz8IjzhZCyK13PJIbOtePf8lJoCDYFJMZLE2iWrcfHKILPn9lipu9KKNL+M3yk6QIDAQAB;";
        }
      ];
  };
}
