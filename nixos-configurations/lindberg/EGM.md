# lindberg

## Overview

Main physical server (AsRock X570): libvirt host for the lindberg-\* VMs, loadbalancer, VPN exit node, local data and backup storage. Legacy operations and hardware notes: [README.md](./README.md). Hardware docs in `docs/` (PDF and photos) are not linked.

## Interface

- Imports: [default.nix:imports] `./applications`, `./backup.nix`, `./disko-config.nix`, `./filesystems.nix`, `./networking.nix`, `./secrets.nix`, `./virtualisation.nix`, `../../defaults/hardware/asrock.nix`.
- `qois.system.physical.enable = true`; `srvos.boot.consoles = mkForce [ "tty0" ]`; `system.stateVersion = "26.05"` [default.nix].
- Networking: `qois.networkd.enable`, hostname from `meta.hosts.lindberg.hostName`, IPv6 disabled, DHCP on `enp5s0` [networking.nix].
- VM network `vms-nat` (meta `lindberg-vms-nat`): bridge, systemd-networkd DHCP server, static lease `52:54:00:59:ff:37` -> `10.247.0.113`, NAT via `enp5s0`, resolved stub listener on the bridge IP [networking.nix:systemd.network.networks."40-vms-nat", networking.nat, services.resolved].
- Remote LUKS unlock: `qois.luks-ssh` (interface `eth0`, port 2222), `boot.initrd.network.udhcpc` [networking.nix].
- `qois.backplane-net.enable`, `qois.vpn-exit-node.enable` [networking.nix].
- Disks via disko: `raid_data` (2 HDD, LUKS, `vg_data`, btrfs `/mnt/data` 12TB), `raid_system` (2 NVMe, LUKS, `vg_system`, btrfs root `hv_lindberg`), LUKS btrfs backup disk `/mnt/backup`, LUKS cache disk with `vg_cache` swap; ESPs `/boot-primary`, `/boot-secondary` [disko-config.nix:disko.devices].
- Boot: `boot.swraid.mdadmConf` with array UUIDs, GRUB mirroredBoots, fwupd ESP location [filesystems.nix].
- libvirtd and `virtiofsd` [virtualisation.nix].
- Backup: `qois.backup-client.includePaths = [ "/mnt/data" ]`; borg job `data-local` to `/mnt/backup/disks/data` at 07:15 with prune policy [backup.nix].
- sops secrets: `tailscale/key` (restarts `tailscale.service`), `backup/data/password`, `backup/data/ssh-key` (restart `borgbackup-job-data-cyprianspitz.service`) [secrets.nix:sops.secrets].
- Children: [applications](./applications/EGM.md).

## Invariants

- All LUKS volumes use `askPassword = true`, so boot needs manual unlock over SSH [disko-config.nix; networking.nix:qois.luks-ssh].
- `/mnt/backup` must be mounted for the `data-local` borg job [backup.nix:data-local.repo].
- Borg repo uses `authenticated` mode with an empty passphrase [backup.nix:encryption].
- mdadm array UUIDs in `filesystems.nix` must match the real arrays [filesystems.nix:boot.swraid.mdadmConf].

## Side Effects

- Hosts NAT, DHCP and DNS for VM guests [networking.nix].
- Daily borg backup writes to the local backup disk [backup.nix].
- Writes GRUB to both ESPs and EFI variables [filesystems.nix].

## Verification

- Build: `nix build .#nixosConfigurations.lindberg.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#lindberg.system-physical`
- All: `nix flake check`
