# Router Role {#_router_role}

The `router` role set is applied on hosts which serve the rule of a SOHO
router.

Features:

- NAT and basic Firewalling (`router`)
- Recursive DNS with `unbound` (DNSSEC validated) (`router-dns`)
- Local DHCP and local DNS hostname resolution with `dnsmasq`
  (`router-dhcp`)
- Wireless with `hostapd` (`router-wireless-ap`)
