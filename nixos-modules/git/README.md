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

## Single Sign-On

Log in with "kanidm" on the login page. Members of the [kanidm](../kanidm/README.md) group
`forgejo-users` may log in, members of `sysadmin` are site administrators. Existing accounts
are linked by email, so keep `idm_people_self_mail_write` in kanidm empty.

## Backup / Restore

1. `systemctl stop forgejo.service`
1. Import Postgresql Database Backup
1. Restore `/var/lib/forgejo`
1. `systemctl start forgejo.service`
