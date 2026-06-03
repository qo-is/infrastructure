# Jellyfin

Jellyfin media server running as a NixOS container (systemd-nspawn) on `lindberg`, configured via [nixflix](https://kiriwalawren.github.io/nixflix/reference/).

## Container

The container is managed by lindberg's NixOS configuration (`nixos-configurations/lindberg/containers.nix`). It runs as a private routed network container with volatile `/var` (state is ephemeral except for bind-mounted paths), but machine-id persists so journal linkage is stable.

```bash
# Container lifecycle
systemctl start container@jellyfin
systemctl stop container@jellyfin
machinectl shell jellyfin  # shell inside container

# Logs (from host)
journalctl -M jellyfin -f
```

## Configuration

The `qois.jellyfin` module wraps nixflix. Key options:

```nix
qois.jellyfin = {
  enable = true;
  domain = "media.qo.is";  # serves at jellyfin.media.qo.is
};
```

## Secret Setup

Before deploying, create both secrets on lindberg:

```bash
sops private/nixos-configurations/lindberg/secrets.sops.yaml
# Add entries:
#   jellyfin/apiKey: <output of: openssl rand -hex 16>
#   jellyfin/adminPassword: <output of: openssl rand -base64 24>
```

Both secrets are passed to the container via systemd credentials (`--load-credential`). The API key is injected into Jellyfin's SQLite database; the admin password is used to create and configure the initial admin user.

## Hardware Acceleration (Optional)

To enable Intel QSV or AMD VAAPI transcoding, add to `nixos-configurations/lindberg/containers.nix`:

```nix
containers.jellyfin = {
  allowedDevices = [{ node = "/dev/dri/renderD128"; modifier = "rwm"; }];
  extraFlags = [ ... "--bind=/dev/dri/renderD128" ];
};
```

And in `nixos-configurations/lindberg-jellyfin/default.nix`:

```nix
nixflix.jellyfin.encoding = {
  hardwareAccelerationType = "vaapi";  # or "qsv"
  enableHardwareEncoding = true;
};
```

See [nixflix hardware acceleration docs](https://kiriwalawren.github.io/nixflix/reference/) for details.
