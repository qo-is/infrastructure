# Backups

We use [borg](https://www.borgbackup.org/) to create encrypted and deduplicated backups.

The backups are encrypted with a (key unlocked by a) secure passphrase that is deployed to the respective node and stored in the [pass repository](https://gitlab.com/qo.is/pass) resp. the sops files in this repository.

Service specific restore instructions are given in the respective services' documentation.

## Host Backups

All hosts make automated backups. See Modules `qois.backup-client` and `qois.backup-server` for details.

## Verify Backups Manually

```bash
ssh root@lindberg-nextcloud.backplane.net.qo.is -- systemctl status borgbackup-job-system-cyprianspitz.service
ssh root@lindberg-webapps.backplane.net.qo.is -- systemctl status borgbackup-job-system-cyprianspitz.service
ssh root@lindberg.backplane.net.qo.is -- systemctl status borgbackup-job-system-cyprianspitz.service
```
