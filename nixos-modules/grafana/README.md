# Grafana

Serves [Grafana](https://grafana.com/) behind nginx with TLS.

## Add new user

1. Get admin credentials: `sops private/nixos-configurations/lindberg-webapps/secrets.sops.yaml`
1. Login at https://monitoring.qo.is
1. Add user at https://monitoring.qo.is/admin/users (new users are not admins by default)

## Storage

Dashboard and user data is stored in PostgreSQL.
