# Grafana

Serves [Grafana](https://grafana.com/) behind nginx with TLS.

## Add new user

1. Get admin credentials: `sops private/nixos-configurations/lindberg-webapps/secrets.sops.yaml`
1. Login at https://monitoring.qo.is
1. Add user at https://monitoring.qo.is/admin/users
   - new users are not admins by default - which is sufficient (least priviledge)
   - Make user "editor" or "admin" of Main Org

## Secrets

Grafana credentials and its data-source encryption key live in
`private/nixos-configurations/lindberg-webapps/secrets.sops.yaml`.

The `secret_key` signs data-source secrets. It has no default since NixOS 26.05 and
must be generated once per instance. Generate and store it with:

```bash
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml '["grafana"]["secret_key"]' "\"`openssl rand -hex 32`\""
```

Changing this key afterwards requires re-encoding existing data-source settings.

## Storage

Dashboard and user data is stored in PostgreSQL.
