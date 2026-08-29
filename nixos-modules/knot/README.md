# Authoritative DNS

[Knot DNS](https://www.knot-dns.cz/) serves our zones authoritatively and signs them with DNSSEC.

- Host records below `net.qo.is`: generated from [`defaults/meta`](../../defaults/meta/)
- Everything else: declared in [`qo-is-zone.nix`](qo-is-zone.nix)
- Zone files: built into the nix store, knot keeps signatures and serial in its journal
- Zone transfers: authorised by source address, since metanet does not support TSIG

## Key Management

```bash
knotc zone-status qo.is.
keymgr qo.is. list
keymgr qo.is. ds                # DS record to upload to the registrar
keymgr qo.is. generate-ksk      # start a KSK rollover
knotc zone-ksk-submitted qo.is. # confirm a rollover manually
```

A KSK rollover publishes CDS/CDNSKEY and only completes once the new DS is visible at the parent.

## Notes

`lindberg-vms.net.qo.is` was dropped: those names pointed into `10.248.0.0/24`, which
`defaults/meta` assigns to `cyprianspitz-vms-nat`. The correct names are
`*.lindberg-vms-nat.net.qo.is`.
