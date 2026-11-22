# cyprianspitz

## Overview

Physical server (AsRock Z790M) on the plessur LAN: loadbalancer, VPN server and exit node, authoritative DNS, backup server and libvirt host. Behind calanda port forwards. Legacy operations and hardware notes: [README.md](./README.md). Hardware docs in `docs/` (PDF and photos) are not linked.

## Interface

- Imports: [default.nix:imports] `./applications`, `./disko-config.nix`, `./filesystems.nix`, `./networking.nix`, `./secrets.nix`, `./virtualisation.nix`, `../../defaults/hardware/asrock-z790m.nix`.
- `qois.system.physical.enable = true`; `system.stateVersion = "26.05"` [default.nix].
- Hostname from `meta.hosts.cyprianspitz.hostName`; IPv6 disabled; static IPv4 on `enp0s31f6` from `plessur-lan` meta; gateway and nameserver calanda [networking.nix:networking.interfaces.enp0s31f6, networking.defaultGateway, networking.nameservers].
- VM network: bridge `vms-nat` from `cyprianspitz-vms-nat` meta, NAT via `enp0s31f6`, dnsmasq DHCP/DNS (range `10.248.0.2,10.248.0.253`) [networking.nix:networking.bridges.vms-nat, networking.nat, services.dnsmasq].
- `qois.initrd-ssh-unlock` (interface `enp0s31f6`, SSH port 2222, host key `/secrets/system/initrd-ssh-key`) [networking.nix:qois.initrd-ssh-unlock].
- `qois.backplane-net.enable`, `qois.vpn-exit-node.enable` [networking.nix].
- Disks via disko: data HDD to mdraid `raid_data` (LUKS `crypted_data`, LVM `vg_data`, btrfs `/mnt/data` with `/backup` and `/backup/.snapshots` subvolumes); two NVMe to mirrored `raid_system` (LUKS, `vg_system`, btrfs root); ESPs `/boot-primary`, `/boot-secondary` [disko-config.nix:disko.devices].
- Boot: GRUB mirroredBoots on both ESPs, `boot.swraid`, fwupd ESP location [filesystems.nix].
- libvirtd (`onShutdown = "shutdown"`) and `virtiofsd` [virtualisation.nix].
- sops secrets: `system/hdd`, `system/initrd-ssh-key` [secrets.nix:sops.secrets].
- Backup: `qois.backup-server` [applications/backup.nix].
- Children: [applications](./applications/EGM.md).

## Invariants

- LUKS password file `/run/secrets/system/hdd.key` must exist at install and boot [disko-config.nix:passwordFile].
- Second data disk is not present yet (`data-2` commented, `TODO`) so `raid_data` is RAID1 on one disk [disko-config.nix:data-2].
- dnsmasq binds to `network-addresses-vms-nat.service` [networking.nix:systemd.services.dnsmasq.bindsTo].
- Static LAN IP must match the lease on calanda [networking.nix:getNetV4Ip; ../calanda/networking.nix].

## Side Effects

- Reboot requires remote LUKS unlock over initrd SSH (port 2222, via calanda 8223) [networking.nix:qois.initrd-ssh-unlock; README.md].
- Runs DHCP/DNS on `vms-nat` and NAT for guests [networking.nix].
- Reads sops secrets at runtime [secrets.nix].

## Verification

- Build: `nix build .#nixosConfigurations.cyprianspitz.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#cyprianspitz.system-physical`
- All: `nix flake check`
