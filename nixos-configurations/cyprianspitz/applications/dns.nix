{ config, ... }:
let
  plessurLanIp = config.qois.meta.network.physical.plessur-lan.hosts.cyprianspitz.v4.ip;
in
{
  qois.knot = {
    enable = true;
    listenAddresses = [ "${plessurLanIp}@53" ];
  };
}
