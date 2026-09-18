{ lib, qoisMeta, ... }:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    pipe
    ;

  # riedbach-ext is assigned dynamically by the ISP and therefore defines no network
  # id, which makes accessing it throw instead of returning a value.
  hasNetworkId = netConfig: (builtins.tryEval netConfig.v4.id).success;

  mkNetwork = netConfig: {
    name = netConfig.domain;
    cidrv4 = "${netConfig.v4.id}/${toString netConfig.v4.prefixLength}";
  };
in
{
  networks = pipe (qoisMeta.network.physical // qoisMeta.network.virtual) [
    (filterAttrs (_name: hasNetworkId))
    (mapAttrs (_name: mkNetwork))
  ];
}
