# Identity Management (Kanidm)

[Kanidm](https://kanidm.github.io/kanidm/stable/) runs on `lindberg-webapps` and serves
[id.qo.is](https://id.qo.is). It is the identity provider for services that support OIDC;
Grafana is currently the only relying party.

Persons are **not** provisioned from this repository — create them in the web UI. Groups
and OAuth2 clients are declared in `nixos-modules/kanidm/default.nix` and in the module of
the consuming service.

## Secrets

The account passwords and every OAuth2 client secret live in the `private` submodule:

```bash
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml \
  '["kanidm"]["admin-password"]' "\"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)\""
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml \
  '["kanidm"]["idm-admin-password"]' "\"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)\""
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml \
  '["kanidm"]["oauth2"]["grafana"]' "\"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)\""
```

Afterwards publish the submodule as described in [the README](../../README.md):

```bash
pushd private
  git commit
  git push
  nix flake prefetch .
popd

git add private
nix flake lock --update-input private
```

Both passwords are re-applied on every start, so changing them in sops is enough.

## First Deploy

The public TLS certificate is issued to nginx by ACME and copied to `/var/lib/kanidm/` by
`security.acme.certs."id.qo.is".postRun`. Until the first issuance succeeds there is no
certificate for kanidm, and `kanidm.service` restarts once a minute until there is. A
public `A`/`AAAA` record for `id.qo.is` pointing at the loadbalancer must exist, otherwise
the challenge fails and kanidm never comes up.

```bash
systemctl status kanidm
ls -l /var/lib/kanidm/{fullchain,key}.pem   # kanidm:kanidm, 0400
curl -s https://id.qo.is/status             # true
```

## Administration

Log in at [id.qo.is/ui](https://id.qo.is/ui) as `idm_admin` with the password from sops to
create persons and manage group membership. `admin` is only needed for schema and system
level changes.

Group membership is appended by provisioning, never overwritten, so members added in the
UI survive a redeploy. Removing a declared group from the repository does delete it.

## Onboarding a Service

Declare the client in the module of the service itself, so its knowledge stays there:

```nix
qois.kanidm.oauth2Clients.<service> = {
  displayName = "Service";
  originUrl = "https://<service>.qo.is/oauth/callback";
  originLanding = "https://<service>.qo.is/";
  roles.admins = [ "Admin" ];         # provisions the group <service>.admins
  secretGroup = "<unix group of the service>";
  restartUnits = [ "<service>.service" ];
};
```

This provisions a `<service>.access` group granting the OIDC scopes, one group per role,
and a sops secret `kanidm/oauth2/<service>` readable by kanidm and the service. Add the
secret as shown above before deploying.

## LDAP

The LDAPS interface listens on port `636`, but no firewall port is opened, so it is only
reachable from `lindberg-webapps` itself:

```bash
ldapsearch -H ldaps://id.qo.is:636 -x -b 'dc=id,dc=qo,dc=is' '(name=<person>)'
```

It reuses the public certificate, so clients must address the server as `id.qo.is`. To
expose it to a host in the backplane network, add the port to
`networking.firewall.interfaces."wg-backplane".allowedTCPPorts`.

## Backup / Restore

`/var/lib/kanidm` is part of the borg backup and holds both the live database and the
nightly online backups kanidm writes to `/var/lib/kanidm/backups` (7 versions kept). Only
the online backups are restore-safe.

1. `systemctl stop kanidm.service`
1. `kanidmd database restore -c /etc/kanidm/server.toml <backup.json>` as user `kanidm`
1. `systemctl start kanidm.service`
