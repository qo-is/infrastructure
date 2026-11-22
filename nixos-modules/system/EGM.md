# system

## Overview

Baseline configuration for every host: srvos server profile, users, nix settings, hardening sysctls, tools, and monitoring defaults. Includes physical-host and VM variants. Unlinked assets: `etc/gitconfig` and `etc/vimrc` (installed to `/etc/gitconfig` and `/etc/vimrc`).

## Interface

- `qois.system.physical.enable` (enable option) [physical.nix:options.qois.system.physical.enable]
- `qois.system.virtual-machine.enable` (enable option) [virtual-machine.nix:options.qois.system.virtual-machine.enable]
- `default.nix` imports `inputs.srvos.nixosModules.server`, `applications.nix`, `overlays.nix`, `physical.nix`, `security.nix`, `virtual-machine.nix` [default.nix:imports]

## Invariants

- Root SSH authorized keys are the keys of all wheel users (except root) plus the CI key `ci@git.qo.is` [default.nix:users.users.root]
- Nix substituters are `attic.qois-infrastructure` (priority 32) and `cache.nixos.org` (40); the nixpkgs-cache is deliberately disabled; GC runs weekly deleting generations older than 90d [default.nix:nix.settings] [default.nix:nix.gc]
- Hardening sysctls (rp_filter, martian logging, redirects, broadcast ICMP) are `mkDefault` [security.nix]
- `nix.nixPath` takes the option default [overlays.nix]
- `qois.vector.enable` is `mkDefault true`; `qois.telegraf.enable`, `qois.backup-client.enable` and `qois.outgoing-server-mail.enable` are set true [default.nix]
- sshd, nix-daemon and nix-gc journal noise is filtered with `LogFilterPatterns` [default.nix:systemd.services]
- Physical: initrd systemd disabled, DHCP wait 900s in initrd [physical.nix:boot.initrd]
- VM: grub enabled, virtio and 9p initrd modules, `system.autoUpgrade.allowReboot = true` [virtual-machine.nix]

## Side Effects

- Enables ACME with `acceptTerms` and email `sysadmin@qo.is` [default.nix:security.acme]
- Enables `fstrim`, btrfs autoscrub, autojump, firewall `allowPing`, `kernel.panic = 20`, `DefaultLimitNOFILE = 4096` [default.nix]
- Installs the common tool set [applications.nix:environment.systemPackages]
- Physical: installs hardware tools, enables `fwupd` (silencing `fwupd-refresh` stderr), `smartd` with mail notifications to `sysadmin@qo.is`, `srvos.server.docs.enable` [physical.nix]
- VM: enables `services.qemuGuest` [virtual-machine.nix:services.qemuGuest]

## Verification

- Run: `nix flake check`
