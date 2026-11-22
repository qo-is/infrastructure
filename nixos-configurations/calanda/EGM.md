# calanda

## Overview

PC Engines APU router and gateway for the plessur networks. Legacy notes: [README.md](./README.md) (title only).

## Interface

- Imports: [default.nix:imports] `./networking.nix`, `./filesystems.nix`, `../../defaults/hardware/apu.nix`.
- `qois.system.physical.enable = true` [default.nix:qois.system.physical.enable]; `system.stateVersion = "26.05"` [default.nix:system.stateVersion].
- Hostname from `meta.hosts.calanda.hostName`, domain `ilanz.fh2.ch`, IPv6 disabled [networking.nix:networking.hostName, networking.domain, networking.enableIPv6].
- Interfaces: `enp4s0` DHCP (WAN), `enp3s0` static IPv4 from `plessur-dmz` meta, `enp2s0` LAN, `wlp5s0` wireless [networking.nix:networking.interfaces, qois.router].
- `qois.router` with DHCP (range `10.1.1.2,10.1.1.249`), recursive DNS and wireless (SSID `hauser`) [networking.nix:qois.router].
- `qois.backplane-net.enable = true` [networking.nix:qois.backplane-net.enable].
- Static DHCP lease for cyprianspitz (needed for initrd SSH LUKS unlock) [networking.nix:services.dnsmasq.settings.dhcp-host].
- DMZ DNS via unbound on the DMZ address [networking.nix:services.unbound.settings.server].
- NAT port forwards to cyprianspitz: tcp 8222->22, 8223->2222, 53 tcp/udp, 80/443 tcp, udp 51824/1666/41641/3478/3479 [networking.nix:networking.nat.forwardPorts].
- Filesystems: btrfs root (`subvol=nixos`, `noatime`) by UUID, swap by UUID, GRUB on `/dev/sda` [filesystems.nix:fileSystems."/", swapDevices, boot.loader.grub].
- Firewall: tcp 80/443 open; udp 53 on `enp3s0` [networking.nix:networking.firewall].
- No sops secrets and no backup config declared in this directory.

## Invariants

- The cyprianspitz LAN IP in the DHCP lease and the forward destinations must match `plessur-lan` meta [networking.nix:services.dnsmasq.settings.dhcp-host, networking.nat.forwardPorts].
- Forwards 8222/8223 reach cyprianspitz SSH and initrd SSH (port 2222) [networking.nix:cyprianspitzPortDst].
- LAN/DMZ IPs and DHCP range partly hardcoded (`TODO: Metaize ips`) [networking.nix:qois.router].

## Side Effects

- Acts as NAT gateway, DHCP and DNS server for the LAN/DMZ; changes can cut connectivity of all plessur hosts [networking.nix:qois.router, networking.nat].
- Writes GRUB to `/dev/sda` [filesystems.nix:boot.loader.grub].

## Verification

- Build: `nix build .#nixosConfigurations.calanda.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#calanda.system-physical`
- All: `nix flake check`
