# Nextcloud

Running on [cloud.qo.is](https://cloud.qo.is), contact someone from the board for administrative tasks.

At this time, we do not enforce any size limits or alike.

We have some globally configured shared folders for our family members.

For user documentation, refer to the [upstream Nextcloud docs](https://docs.nextcloud.com/server/stable/user_manual/en/). Clients can be downloaded from [nextcloud.com/install](https://nextcloud.com/install/).

## Backup / Restore

1. Stop all related services: nextcloud, php-fpm, redis etc.
2. (mabe dump redis data?)
3. Import Database Backup
4. Restore `/var/lib/nextcloud`, which is currently a bind mount on `lindberg`'s `/mnt/data` volume
5. Resync nextcloud files and database, see [nextcloud docs](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/restore.html)
