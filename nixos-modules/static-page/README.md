# Static Pages

This module enables static nginx sites, with data served from "/var/lib/nginx-$domain/.local/state/nix/profiles/webroot".

To deploy the site, a user `nginx-$domain` is added, of which a `webroot` profile can be deployed, e.g. with deploy-rs.
