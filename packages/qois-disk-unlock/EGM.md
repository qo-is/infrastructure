# qois-disk-unlock

## Overview

Unlocks a host's encrypted disks by sending the sops-stored passphrase to its initrd SSH server.

## Interface

- Derivation `qois-disk-unlock`, description "Unlock a host's encrypted disks through its initrd ssh server" [default.nix:writeShellApplication]
- CLI: `qois-disk-unlock <host>`, supported hosts `cyprianspitz` (via `root@calanda.plessur-ext.net.qo.is` port 8223) and `lindberg` (`root@lindberg.riedbach-ext.net.qo.is` port 2222) [script.bash:case HOST]
- Runtime deps: `gitMinimal`, `openssh`, `self.packages.${system}.sops` [default.nix:runtimeInputs]

## Invariants

- Exits 1 without a host or for hosts not listed in the case statement [script.bash:HOST]
- Passphrase is read from `["system"]["hdd"]` of the host's `secrets.sops.yaml` in the private submodule [script.bash:PASSPHRASE]
- Passphrase is written to the ssh tty after `PROMPT_DELAY_SECONDS=3` [script.bash:PROMPT_DELAY_SECONDS]
- The SSH exit status is ignored since the host drops the session when boot continues [script.bash:ssh]

## Side Effects

- Decrypts a secret with sops [script.bash:PASSPHRASE]
- Opens an SSH session with `StrictHostKeyChecking=accept-new` and `-tt` [script.bash:ssh]

## Verification

- Run: `nix build .#qois-disk-unlock`
