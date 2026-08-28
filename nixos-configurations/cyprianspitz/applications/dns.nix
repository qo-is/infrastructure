{ config, ... }:
let
  plessurLanIp = config.qois.meta.network.physical.plessur-lan.hosts.cyprianspitz.v4.ip;
in
{
  qois.knot = {
    enable = true;
    # dnsmasq already serves the vms-nat bridge on port 53, so knot only binds the
    # address that receives calanda's port forwarding.
    listenAddresses = [ "${plessurLanIp}@53" ];
  };
}
