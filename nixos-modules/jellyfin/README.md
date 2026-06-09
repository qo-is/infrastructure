# Jellyfin

Jellyfin media server configured via [nixflix](https://kiriwalawren.github.io/nixflix/reference/).

## Configuration

The `qois.jellyfin` module wraps nixflix and serves Jellyfin at `jellyfin.${domain}` (a subdomain of the configured primary domain):

```nix
qois.jellyfin = {
  enable = true;
  domain = "media.qo.is";  # serves at jellyfin.media.qo.is
};
```

The host running the container is responsible for the systemd-nspawn integration, secret materialization, and bind-mounts (see the host's `containers.nix` for an example).

## Secret Setup

Both the Jellyfin API key and the initial admin password are passed into the container as systemd credentials (`--load-credential`). Create them in the host's secrets file before deploying:

```bash
SECRETS_FILE=private/nixos-configurations/<hostname>/secrets.sops.yaml

sops set $SECRETS_FILE '["jellyfin"]["apiKey"]' "\"$(openssl rand -hex 16)\""
sops set $SECRETS_FILE '["jellyfin"]["adminPassword"]' "\"$(openssl rand -base64 24)\""
```

The API key is injected into Jellyfin's SQLite database; the admin password is consumed by `jellyfin-credential-setup.service` and used to provision the initial `admin` user.

## Admin Login

Username is `admin` (set in `default.nix`). Retrieve the password:

```bash
sops -d --extract '["jellyfin"]["adminPassword"]' $SECRETS_FILE
```

## Hardware Acceleration (Optional)

To enable Intel QSV or AMD VAAPI transcoding, bind `/dev/dri/renderD128` into the container on the host (`containers.<name>.allowedDevices` + `extraFlags = [ "--bind=/dev/dri/renderD128" ]`) and configure nixflix encoding:

```nix
nixflix.jellyfin.encoding = {
  hardwareAccelerationType = "vaapi";  # or "qsv"
  enableHardwareEncoding = true;
};
```

See [nixflix hardware acceleration docs](https://kiriwalawren.github.io/nixflix/reference/) for details.
