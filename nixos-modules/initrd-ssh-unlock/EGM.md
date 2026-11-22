# initrd-ssh-unlock

## Overview

Remote LUKS unlock over SSH in the systemd initrd. Connect with `ssh -o RequestTTY=force -p <sshPort> root@<host>`; each authorized key forces `systemctl default`, which prompts for pending passphrases.

## Interface

- `qois.initrd-ssh-unlock.enable` (bool, default false) [default.nix:enable]
- `qois.initrd-ssh-unlock.interface` (str, required) [default.nix:interface]
- `qois.initrd-ssh-unlock.ip` (str, default `dhcp`; or CIDR) [default.nix:ip]
- `qois.initrd-ssh-unlock.gateway` (nullOr str, default null) [default.nix:gateway]
- `qois.initrd-ssh-unlock.sshHostKey` (str or path, required) [default.nix:sshHostKey]
- `qois.initrd-ssh-unlock.sshPort` (port, default 2222) [default.nix:sshPort]

## Invariants

- Forces `boot.initrd.systemd.enable = true` and clears `boot.initrd.network.udhcpc.extraArgs` (legacy busybox initrd settings are incompatible) [default.nix:mkForce]
- Network is `10-<interface>` via systemd-networkd, DHCP ipv4 when `ip == "dhcp"`, otherwise static address and optional gateway route; required online `routable` [default.nix:boot.initrd.systemd.network]
- Authorized keys are the SSH keys of all users in group `wheel`, each prefixed with `command="systemctl default"` [default.nix:authorizedKeys]
- The host key is stored unencrypted in the initrd; the normal host key should not be used [default.nix:sshHostKey description]

## Side Effects

- Starts an SSH server in the initrd on `sshPort` [default.nix:boot.initrd.network.ssh]
- Enables initrd networking (systemd-networkd) [default.nix:boot.initrd.systemd.network]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-initrd-ssh-unlock` (test in `./test.nix`, `./test.py`; fixture keys in `./test-keys/`)
