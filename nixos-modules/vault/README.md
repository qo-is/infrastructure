# Vaultwarden / Bitwarden

To use our Vaultwarden instance, you can use the regular
[Bitwarden apps](https://bitwarden.com/download/) with our custom server when logging in:

Username: `first.lastname@qo.is`\
Server Name: `https://vault.qo.is`

## Create Accounts

We currently [allow signups](https://vault.qo.is/#/register) for `@qo.is` email addresses.

Please instruct users to:

- use their full `firstname.lastname@qo.is` email so users may be connected to a LDAP database in the future
- remember that the login password is used to encrypt the password database and should therefor be good.
- the password cannot be reset without loosing all the passwords.
  Use of [Emergency Contacts](https://bitwarden.com/help/emergency-access/) or Organizations may be advisable.

## Administration

An admin panel is available under [vault.qo.is/admin](https://vault.qo.is/admin).
The password is saved in the pass database under `vaultwarden-admin`.

In the administration panel, users and organizations may be managed.
Instance settings should be changed with the nixos module in the infrastructure repository only.

## Backup / Restore

1. `systemctl stop vaultwarden.service`
1. Import Postgresql Database Backup
1. Restore `/var/lib/bitwarden_rs`
1. `systemctl start vaultwarden.service`
1. Click `Force clients to resync` in the [Administration interface under _Users_](https://vault.qo.is/admin/users/overview)
