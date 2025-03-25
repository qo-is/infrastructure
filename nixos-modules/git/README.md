# Git

## Configuration for Git Clients

### Authentication

To use oauth authentication, your git configuration should have something like:

```ini
[credential]
  helper = "libsecret"
  helper = "cache --timeout 21600"
  helper = "/usr/bin/git-credential-oauth" # See https://github.com/hickford/git-credential-oauth
```

On NixOS with HomeManager, this can be achieved by following home-manager config:

```nix
programs.git.extraConfig.credential.helper = [ "libsecret" "cache --timeout 21600" ];
programs.git-credential-oauth.enable = true;
```

## Administration

### Create Accounts

Accounts can be created by an admin in the [administrator area](https://git.qo.is/admin).

- use their full `firstname.lastname@qo.is` email so users may be connected to a LDAP database in the future
- Username should be in form of "firstnamelastname" (Forgejo doesn't support usernames with dots)

To create a new admin user from the commandline, run:

```bash
sudo -u forgejo 'nix run nixpkgs#forgejo -- admin user create --config ~custom/conf/app.ini --admin --email "xy.z@qo.is" --username firstnamelastname --password Chur7000'
```

## Backup / Restore

1. `systemctl stop forgejo.service`
1. Import Postgresql Database Backup
1. Restore `/var/lib/forgejo`
1. `systemctl start forgejo.service`
