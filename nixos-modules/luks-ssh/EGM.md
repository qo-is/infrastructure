# luks-ssh

## Overview

Remote LUKS unlock: starts an SSH server and network in the initrd so the disk passphrase can be entered remotely.

## Interface

- `qois.luks-ssh.enable` (bool) [default.nix:options.qois.luks-ssh.enable]
- `qois.luks-ssh.interface` (str, required) [default.nix:options.qois.luks-ssh.interface]
- `qois.luks-ssh.ip` (str, default `"dhcp"`) [default.nix:options.qois.luks-ssh.ip]
- `qois.luks-ssh.gateway` (str, default null) [default.nix:options.qois.luks-ssh.gateway]
- `qois.luks-ssh.netmask` (str, default null) [default.nix:options.qois.luks-ssh.netmask]
- `qois.luks-ssh.sshHostKey` (str, default `/secrets/initrd_ssh_key_ed25519`) [default.nix:options.qois.luks-ssh.sshHostKey]
- `qois.luks-ssh.sshPort` (int 1..65535, default 2222) [default.nix:options.qois.luks-ssh.sshPort]

## Invariants

- Authorized keys are the keys of all users in group `wheel` [default.nix:authorizedKeys]
- With a static `ip`, `gateway` and `netmask` must be set (not asserted; evaluation fails on the null interpolation otherwise); they are placed on the kernel `ip=` parameter. With `"dhcp"`, udhcpc is enabled instead [default.nix:boot.kernelParams] [default.nix:boot.initrd.network.udhcpc.enable]
- The initrd host key is stored unencrypted, so it must not be the normal host key [default.nix:options.qois.luks-ssh.sshHostKey]

## Side Effects

- Enables `boot.initrd.network` and initrd SSH on `sshPort` [default.nix:boot.initrd.network]
- Appends `cryptsetup-askpass` to `/root/.profile` in the initrd [default.nix:postCommands]
- Brings `cfg.interface` down after mounting root [default.nix:boot.initrd.postMountCommands]

## Verification

- Run: `nix flake check`
