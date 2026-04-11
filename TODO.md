# TODO: Clean up config covered by SrvOS

> **Do not implement these yet.**
> These are tracking items for a future cleanup pass, once the SrvOS integration has been
> verified working in production. All entries currently coexist safely — SrvOS uses
> `lib.mkDefault` so our values take precedence where we've set them explicitly.

## Redundant configuration to remove

| Location | Config | Covered by SrvOS |
|---|---|---|
| `nixos-modules/system/default.nix:46` | `users.mutableUsers = false` | `nixos/server/default.nix:83` |
| `nixos-modules/system/default.nix:107-110` | `services.openssh.enable` + `settings.PasswordAuthentication = false` | `nixos/common/openssh.nix` |
| `nixos-modules/system/default.nix:102-105` | `networking.firewall.allowedTCPPorts = [ 22 ]` | `nixos/server/default.nix:56,64` |
| `nixos-modules/system/default.nix:41-44` | `RuntimeWatchdogSec`, `RebootWatchdogSec` | `nixos/server/default.nix:115-120` (SrvOS uses different values — review before removing) |
| `nixos-modules/system/default.nix:66` | `security.pam.services.su.forwardXAuth = mkForce false` | `nixos/server/default.nix:25-26` (stub-ld / no xlibs) |
| `nixos-modules/system/default.nix:79-89` | `nix.settings.trusted-users` | `nixos/common/nix.nix:12` (also sets `@wheel` — verify `root` is still included) |
| `nixos-modules/system/default.nix:96-98` | `nix.extraOptions` experimental-features | `nixos/shared/common/nix.nix:11-15` (also enables `nix-command` + `flakes`) |
| `nixos-modules/system/security.nix` | sysctl hardening (rp_filter, ICMP redirects, send_redirects) | Overlaps with SrvOS server hardened profile — review for full coverage |
| `nixos-modules/system/default.nix:123-128` | `programs.vim` + `defaultEditor = true` | `nixos/server/default.nix:48-53` |
| `nixos-modules/system/default.nix:25` | `boot.loader.timeout = 2` | `nixos/server/default.nix:31-32` (SrvOS sets grub `configurationLimit = 5`) |

## Explicit overrides to revisit

These are overrides we added to counteract SrvOS defaults. They may be adoptable once the
relevant subsystems have been migrated.

| Override | Location | What to do |
|---|---|---|
| `services.userborn.enable = false` | `nixos-modules/system/default.nix` | Review if userborn can be enabled (requires verifying compatibility with the `private` module's user management) |
| `boot.initrd.systemd.enable = false` | `nixos-modules/system/default.nix` | Review if systemd initrd can be adopted (requires migrating `luks-ssh` and `udhcpc`-based initrd networking) |

## Notes

- **Documentation**: SrvOS disables man pages and docs by default (`lib.mkDefault false` in
  `nixos/shared/server.nix:26-29`). Currently overridden implicitly. Decide whether to keep
  docs enabled or adopt the SrvOS default.
