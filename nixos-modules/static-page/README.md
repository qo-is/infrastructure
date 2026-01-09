# Static Pages

This module enables static nginx sites, with data served from "/nix/var/nix/profiles/per-user/nginx-${domain}/webroot".

To deploy the site, a user `nginx-$domain` is added, of which a `webroot` profile can be deployed, e.g. with deploy-rs.
