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

While implementing a test, it's advisable to debug problems via the interactive driver:

```bash
nix run .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-testNameAsInDerivationName.driverInteractive
```

Some errors are hidden when commands are executed through the testing framework.

See [upstream documentation](https://nixos.org/manual/nixos/stable/#sec-running-nixos-tests-interactively) for more details.

## Hints for Writing Tests

### Curl and Grep

Avoid `curl ... | grep -q`, because grep breaks the pipe on the first match which leads to a 23 exit code.
Rather use `grep -c` to just show the count of matches.

### Telegraf Metric Integration

When a module configures telegraf inputs, add a test subtest verifying that the
expected metric family appears in telegraf output at port 9273. For services with nginx-fronted
metrics paths, verify that the `/metrics` endpoint returns HTTP 200 from localhost
(access is allowed from `127.0.0.1` and the backplane `10.250.0.0/24`, denied otherwise).
