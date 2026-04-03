# MicroVM Platform Module

Lightweight microvm.nix-based VMs running on host machines (primarily lindberg).

## Adding a new microvm service

1. **Create a guest module** in `nixos-modules/<service-name>/default.nix`:

   - Define `qois.<service-name>.enable` and service-specific options
   - Configure the NixOS service, firewall ports, etc.
   - This module runs _inside_ the guest VM

1. **Declare the VM** in the host's applications config (e.g., `nixos-configurations/lindberg/applications/microvm.nix`):

   ```nix
   qois.microvm.services.<name> = {
     enable = true;
     vcpus = 2;
     mem = 2048;
     hostAddress = "10.249.0.X";   # Next even number
     guestAddress = "10.249.0.Y";  # X + 1
     guestModules = [({ ... }: {
       qois.<service-name>.enable = true;
     })];
   };
   ```

1. **Lock and build**: `nix flake lock && nix build .#nixosConfigurations.<host>.config.system.build.toplevel`

## Network addressing

Subnet: `10.249.0.0/24` (point-to-point /32 links)

| VM | Host-side | Guest-side |
| -------- | ------------ | ------------ |
| postgres | 10.249.0.2 | 10.249.0.3 |
| jellyfin | 10.249.0.4 | 10.249.0.5 |
| _next_ | 10.249.0.6 | 10.249.0.7 |

Each VM gets a tap interface `vm-<name>` with a /32 point-to-point link. The host acts as gateway.

## Secrets

Declare secrets at the platform level and grant access per-VM:

```nix
qois.microvm.secrets.<secret-name> = {
  generator = "${pkgs.pwgen}/bin/pwgen -s 32 1";  # default
  fileName = "password";                            # default
};

qois.microvm.services.<vm>.secrets = [ "<secret-name>" ];
```

- Secrets are generated on the host in `/dev/shm/microvm-secrets/<name>/<fileName>`
- Each VM only gets virtiofs mounts for secrets listed in its `.secrets`
- Inside the guest: `/run/microvm-secrets/<secret-name>/<fileName>`
- Secrets live on tmpfs and are regenerated on host reboot

## Data shares (virtiofs)

```nix
qois.microvm.services.<vm>.shares = [{
  tag = "media";
  source = "/mnt/data/media";    # host path
  mountPoint = "/media";          # guest mount
}];
```

## Service dependencies

```nix
qois.microvm.services.jellyfin.dependsOn = [ "postgres" ];
```

This ensures `microvm@postgres.service` starts before `microvm@jellyfin.service`.

## Guest module pattern

Guest modules are `deferredModule` values passed via `guestModules`. They are standard NixOS modules that configure services inside the VM. The platform module handles VM lifecycle, networking, and virtiofs mounts.
