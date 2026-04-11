# TODO: Clean up config covered by SrvOS

## Explicit overrides to revisit

These are overrides we added to counteract SrvOS defaults. They may be adoptable once the
relevant subsystems have been migrated.

| Override | Location | What to do |
|---|---|---|
| `services.userborn.enable = false` | `nixos-modules/system/default.nix` | Review if userborn can be enabled (requires verifying compatibility with the `private` module's user management) |
| `boot.initrd.systemd.enable = false` | `nixos-modules/system/default.nix` | Review if systemd initrd can be adopted (requires migrating `luks-ssh` and `udhcpc`-based initrd networking) |
