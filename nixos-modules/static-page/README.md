# Static Pages

This module enables static nginx sites, with data served from "/var/lib/nginx-$domain/root".

To deploy the site, a user `nginx-$domain` is added, of which a `root` profile in the home folder can be deployed, e.g. with deploy-rs.
