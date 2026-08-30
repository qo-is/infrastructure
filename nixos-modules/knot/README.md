# Authoritative DNS

[Knot DNS](https://www.knot-dns.cz/) serves our zones authoritatively and signs them with DNSSEC.

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
