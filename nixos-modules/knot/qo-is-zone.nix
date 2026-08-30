{ config, lib, ... }:

let
  inherit (lib)
    attrNames
    attrValues
    concatMap
    filter
    hasSuffix
    mapAttrsToList
    optional
    pipe
    removeSuffix
    ;

  domain = "qo.is";

  inherit (config.qois.meta.network.physical) plessur-ext riedbach-ext;
  lindberg = riedbach-ext.hosts.lindberg;

  mkRecord = type: name: data: {
    name = if name == "" then "${domain}." else "${name}.${domain}.";
    inherit type data;
  };
  mkA = mkRecord "A";
  mkAAAA = mkRecord "AAAA";
  mkCNAME = mkRecord "CNAME";
  mkMX = mkRecord "MX";
  mkNS = mkRecord "NS" "";
  mkSRV = mkRecord "SRV";
  mkTXT = mkRecord "TXT";

  networks =
    attrValues config.qois.meta.network.physical ++ attrValues config.qois.meta.network.virtual;

  metaRecords = concatMap (
    network:
    concatMap
      (
        { fqdn, host }:
        let
          name = removeSuffix ".${domain}" fqdn;
        in
        [ (mkA name host.v4.ip) ] ++ optional (host.v6 != null) (mkAAAA name host.v6.ip)
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
  foreignHostRecords = mapAttrsToList mkA {
    "stompert.backplane.net" = "10.250.0.5";
    "stompert.eem-ext.net" = "81.204.174.111";
    "router.lattenbach-ext.net" = "5.226.148.126";
    "calanda.plessur.net" = "85.195.200.253";
  };

  # vpn.qo.is is served by calanda, not by the loadbalancer.
  serviceNames =
    pipe config.qois.loadbalancer.domains [
      attrNames
      (filter (name: hasSuffix ".${domain}" name && name != "vpn.${domain}"))
      (map (removeSuffix ".${domain}"))
    ]
    ++ [
      "id"
      "media"
      "jellyfin.media"
    ];

  serviceAliases = map (name: mkCNAME name "${lindberg.fqdn}.") serviceNames;
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
        (mkNS "ns1.${domain}.")
        (mkNS "ch.ch-inter.net.")
        (mkNS "de.ch-inter.net.")
        (mkNS "nl.ch-inter.net.")
        (mkA "ns1" plessur-ext.hosts.calanda.v4.ip)

        (mkA "" lindberg.v4.ip)
        (mkAAAA "stompert.eem-ext.net" "2a02:a449:0047:0001:020d:b9ff:fe4a:7a49")

        (mkCNAME "vpn" "calanda.plessur-ext.net.${domain}.")
        (mkCNAME "*.vpn" "vpn.${domain}.")
        (mkCNAME "*.vpn.net" "vpn.${domain}.")

        (mkMX "" "0 mx.${domain}.")
        (mkA "mx" "149.126.4.120")
        (mkAAAA "mx" "2a01:ab20:0000:0004:0000:0000:0000:0120")
        (mkCNAME "autoconfig" "maildiscovery.cyon.ch.")
        (mkSRV "_autodiscover._tcp" "0 0 443 maildiscovery.cyon.ch." // { ttl = 3600; })
        (mkCNAME "openpgpkey" "wkd.keys.openpgp.org.")
        (mkTXT "" "v=spf1 include:spf.protection.cyon.net -all")
        (mkTXT "default._domainkey" "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvqdVBBTioPZafUcajXYogvOb76Dnnu7K3PQtjafKpM4Am40L17K5I1UjTnuxoaUTQYVQiAKWnI3LoaYPUTWBDxYITv2oiyr/RtBkmetMyGrk/Fvew9Ankp9T5H4gASZqUqg/AWKXTsrxL5AqfULAlfkdOidwxrxMoH7IOWmfkNCb/sPUbnEq3HqKoOpoBduVHLCO4sDj10zbYsK3X+2Ju+k1ANiMfrB6GWJ1zmVwEGE34q1ztbX9cWbkpu1JgvLXde9gFNW9b95egHPgaqwPYOwz8IjzhZCyK13PJIbOtePf8lJoCDYFJMZLE2iWrcfHKILPn9lipu9KKNL+M3yk6QIDAQAB;")
      ];
  };
}
