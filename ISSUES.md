# Open issues from the EGM bootstrap (2026-11-22)

These issues were found while writing the `EGM.md` contracts. They remain open after the triage in the `cleanup` branch. Items that were fixed, or closed as invalid or intended, are removed.

## Refactors

- `nixos-modules/luks-ssh`: `gateway` and `netmask` are `types.str` with `default = null`, and a static `ip` without them fails on string interpolation. The module is used only by lindberg (dhcp), while cyprianspitz uses `initrd-ssh-unlock`. Migrate lindberg to `initrd-ssh-unlock` and delete `luks-ssh`. Needs a manual initrd unlock check on lindberg after deploying.
- `nixos-modules/static-page`: default pages are one `mkDefault` attrset in `default-pages.nix`, so a host defining `pages` replaces all three defaults instead of merging. The file is imported regardless of `qois.static-page.enable`, and the loadbalancer on lindberg reads `qois.static-page.pages` there although the module is disabled on that host. Moving the defaults under `mkIf enable` would therefore drop the static domains from the loadbalancer. Decide where domain lists live (host config of lindberg-webapps, shared meta) before changing it.
- `nixos-configurations/calanda/networking.nix`: LAN/DMZ IPs and DHCP range hardcoded (`TODO: Metaize ips`).

## Behaviour

- `nixos-modules/kanidm/mail-sender-token.sh`: when the stored token is valid the script exits early, so `idm_message_senders` membership is not re-ensured if it was removed. A fix needs an admin `authenticate` on every run. Test: remove the membership in the kanidm VM test, rerun the unit, assert it is restored.
- `nixos-modules/vpn-server/default.nix`: headscale is ordered after `wireguard-wg-backplane.service`, but it binds `127.0.0.1`, so the ordering may be unnecessary. Check what else in its config needs the backplane at start before removing it.

## Features and hardware

- IPv6 is disabled in `nixos-configurations/calanda/networking.nix`, `nixos-modules/router/default.nix` and `nixos-modules/nixpkgs-cache/default.nix` (TODOs).
- `nixos-configurations/cyprianspitz/disko-config.nix`: second data disk `data-2` missing, so `raid_data` is RAID1 on one disk. Blocked on hardware.
