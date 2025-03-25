# Tests

`nix flake check` currently:

- builds all nixos-configurations
- builds all packages
- runs all [nixos-module tests](#module-tests)
- checks all deployment configurations
- checks repository formatting.

## Module Tests

We test our nixos modules with [NixOS tests](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests).
Running nixos tests requires QEMU virtualisation, so make sure you have KVM virtualisation support enabled.

Run all: `nix build .#checks.x86_64-linux.nixos-modules`\
Run single test: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-testNameAsInDerivationName`

### Run Test Interactively

```bash
nix run .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-testNameAsInDerivationName.driverInteractive
```

See [upstream documentation](https://nixos.org/manual/nixos/stable/#sec-running-nixos-tests-interactively) for more details.
