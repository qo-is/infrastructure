# Identity Management (Kanidm)

[Kanidm](https://kanidm.github.io/kanidm/stable/) serves [id.qo.is](https://id.qo.is) and
is the identity provider for services that support OIDC.

Persons are **not** provisioned from this repository — create them in the web UI. Groups
and OAuth2 clients are declared in `nixos-modules/kanidm/default.nix` and in the module of
the consuming service.

## Secrets

The account passwords are host secrets. OAuth2 client secrets go into
`private/nixos-modules/kanidm/<relying party host>.sops.yaml`, which is encrypted for that
host and for the host running kanidm:

```bash
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml \
  '["kanidm"]["admin-password"]' "\"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)\""
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml \
  '["kanidm"]["idm-admin-password"]' "\"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)\""
sops set private/nixos-modules/kanidm/lindberg-webapps.sops.yaml \
  '["kanidm"]["oauth2"]["grafana"]' "\"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)\""
```

## Administration

Log in at [id.qo.is/ui](https://id.qo.is/ui).

| Account | Use for |
| ----------- | ------------------------------------------ |
| `idm_admin` | persons, credentials, group membership |
| `admin` | schema, domain and other system level changes |

Provisioned group membership is appended, never overwritten, so members added in the UI
survive a redeploy. Removing a declared group from the repository does delete it.

## LDAP

Port `636` is only reachable from the host itself; no firewall port is opened.

```bash
ldapsearch -H ldaps://id.qo.is:636 -x -b 'dc=id,dc=qo,dc=is' '(name=<person>)'
```

## Backup / Restore

- `/var/lib/kanidm` — in the borg backup
- live sqlite database — not restore-safe
- `/var/lib/kanidm/backups` — kanidm's nightly online backups, 2 versions, restore-safe

1. `systemctl stop kanidm.service`
1. `kanidmd database restore -c /etc/kanidm/server.toml <backup.json>` as user `kanidm`
1. `systemctl start kanidm.service`
