# Issues found during EGM bootstrap (2026-11-22)

Code and documentation issues found while writing the `EGM.md` contracts and running the drift report (`2026-11-22_DRIFT_REPORT.md`). None of these were changed; they need triage.

## Likely bugs

- `checks/packages/default.nix` is not imported by `checks/default.nix`, so no check builds all packages. It is also broken as written: `attrValues self.packages` yields per-system attrsets, not derivations.
- `nixos-modules/loadbalancer/default.nix`: `www.resourcee.fh2.ch` maps to `workstations-9001`, which only defines an http backend, so HTTPS requests for it hit a nonexistent backend. Unmapped Host/SNI names also resolve to `-http`/`-https` (no `default_backend`).
- `packages/auto-deploy/script.bash`: the known-hosts `nix build .#nixosConfigurations.lindberg...` is relative to the current directory, while `nix eval` uses `${FLAKE_ROOT}`. It fails or builds the wrong flake when run outside the repo root.
- `packages/auto-deploy/script.bash`: under `set -e`, a host that exhausts its 3 retries makes `retry` return 1 and aborts the script; remaining hosts are not deployed.
- `packages/sops-rekey/default.nix`: `sops updatekeys` runs without `-y`, so every file prompts interactively.
- `nixos-configurations/cyprianspitz/disko-config.nix`: LUKS `passwordFile = "/run/secrets/system/hdd.key"`, but the declared sops secret `system/hdd` lands at `/run/secrets/system/hdd`. Fine if `.key` is only created manually at install time; otherwise a reinstall via disko needs that file.

## Missing assertions (evaluation fails with unclear errors)

- `nixos-modules/luks-ssh/default.nix`: with a static `ip`, `gateway` and `netmask` (default `null`) must be set; nothing asserts it, so it fails on string interpolation.
- `nixos-modules/initrd-ssh-unlock/default.nix`: the `gateway` description says it is required for a static `ip`, but nothing enforces it.
- `nixos-modules/backplane-net/default.nix`: no assertion that the host exists in `qois.meta.network.virtual.<netName>.hosts`.
- `nixos-modules/meta/network.nix`: `mkFqdn` reads `config.qois.meta.hosts.${host}.hostName`, so each network host needs a `qois.meta.hosts` entry. `persistentKeepalive` has no range check although its description says 1..65535.
- `nixos-modules/postgresql/default.nix`: setting `upgradeFrom` without `package` (default `null`) fails evaluation.
- `packages/sops-config/default.nix`: evaluation fails if `lindberg-webapps` (`kanidmHost`) has no `sshKey`.
- `checks/nixos-modules/default.nix`: tests are selected by `test.nix`; a `test.nix` without `test.py` fails at `readFile`.

## Surprising behaviour

- `nixos-modules/static-page`: default pages are one `mkDefault` attrset in `default-pages.nix`, so any host defining `pages` replaces all three defaults instead of merging. `default-pages.nix` is imported regardless of `qois.static-page.enable`.
- `nixos-modules/kanidm/mail-sender-token.sh`: when the stored token is valid the script exits early, so `idm_message_senders` membership is not re-ensured if it was removed.
- `nixos-modules/meta/hosts.nix`: the `sshKey` regex requires exactly 68 base64 chars and allows no trailing comment.
- `packages/auto-deploy` and `packages/diff-closures` call `nix` without listing it in `runtimeInputs`.

## Dead or unused code

- `nixos-modules/router/default.nix`: option `qois.router.wirelessInterfaces` is declared but never read.
- `defaults/hardware/apu1.nix` is imported by no host.
- `nixos-modules/vpn-server/default.nix`: ACL host alias `clients` is unused by any rule.

## Stale comments and docs

- `nixos-modules/static-page/default.nix`: the `domain` option description says root `/var/lib/nginx-$domain/root`; the code uses `<home>/.local/state/nix/profiles/webroot`.
- `nixos-modules/vpn-server/default.nix`: a comment says headscale binds to the backplane VPN IP; it binds `127.0.0.1`.
- `defaults/meta/network.md`: `{{#include ../backplane-net/README.md}}` points to a nonexistent file (the module is `nixos-modules/backplane-net/`).
- `AGENTS.md`: says `flake.nix` passes a shared `importParams` record; it actually passes layered `inputSubset*` sets (see `flake.nix`).

## Code style

- `packages/sops-config/default.nix` uses `with lib;` and `deploy/default.nix` uses `with pkgs.lib;`, which CODESTYLE.md forbids.

## Open TODOs in code

- `nixos-configurations/calanda/networking.nix`: LAN/DMZ IPs and DHCP range hardcoded (`TODO: Metaize ips`).
- `nixos-configurations/cyprianspitz/disko-config.nix`: second data disk `data-2` missing, so `raid_data` is RAID1 on one disk.
- `nixos-modules/nixpkgs-cache/default.nix` and `nixos-modules/router/default.nix`: IPv6 disabled (TODO).
