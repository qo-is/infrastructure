# Authoritative DNS

[Knot DNS](https://www.knot-dns.cz/) serves our zones authoritatively and signs them with DNSSEC.

Host records below `net.qo.is` are generated from [`defaults/meta`](../../defaults/meta/), everything
else is declared in [`qo-is-zone.nix`](qo-is-zone.nix). Zone files are built into the nix store,
so knot keeps all changes — signatures and serial included — in its journal under `/var/lib/knot`.
**That directory holds the DNSSEC private keys** and is included in the host backup.

## Zone Transfer Secret

```bash
sops set private/nixos-configurations/cyprianspitz/secrets.sops.yaml '["knot"]["xfr-secret"]' "\"`openssl rand -base64 32`\""
```

Then add `"knot/xfr-secret" = { };` to the host's `sops.secrets`. Secondaries are authorised by
address alone as long as the secret is not declared.

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
