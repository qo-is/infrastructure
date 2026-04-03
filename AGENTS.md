# AGENTS.md

## Commands

```bash
nix develop                    # Enter dev shell (direnv auto-activates via .envrc)
nix fmt                        # Auto-format all files (treefmt: nixfmt, deadnix, jsonfmt, yamlfmt, mdformat, ruff, shfmt)
nix flake check                # Run all checks: build configs, build packages, run module tests, check deploy, check formatting

# Build a single host
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Module tests (require KVM)
nix build .#checks.x86_64-linux.nixos-modules                                              # All tests
nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-<testName>                # Single test
nix run .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-<testName>.driverInteractive # Interactive

# Secrets (SOPS-nix, requires access to private submodule)
sops <file>                    # Edit encrypted secrets file
sops-rekey                     # Rekey all secrets after key changes

# After changing secrets in private/:
pushd private && git commit && git push && nix flake prefetch . && popd
git add private && nix flake lock --update-input private

# Deployment (deploy-rs, requires VPN connection to backplane network)
auto-deploy <profile>          # Deploy a profile: system-vm, system-physical, system-ci
```

## Architecture

NixOS infrastructure-as-code repository (Nix Flakes, x86_64-linux, nixpkgs nixos). All services are defined declaratively as NixOS modules — no Docker, Terraform, or Pulumi.

### Flake Structure

`flake.nix` loads each output section from its subdirectory, passing a shared `importParams` record containing all flake inputs plus `pkgs`, `system`, and `deployPkgs`. Each subdirectory's `default.nix` receives these params.

```
flake.nix
├── checks/          → flake checks (builds, tests, formatting)
├── deploy/          → deploy-rs profiles (system-vm, system-physical, system-ci)
├── dev-shells/      → development shell with tools
├── nixos-configurations/  → per-host NixOS configs
├── nixos-modules/   → reusable NixOS modules (31 modules)
├── packages/        → custom packages (auto-deploy, docs, sops wrapper)
├── lib/             → shared utilities
├── defaults/        → hardware profiles + network/host metadata
└── private/         → git submodule with SOPS-encrypted secrets
```

### Auto-Discovery

`lib/default.nix` provides `loadSubmodulesFrom(basePath)` which finds all subdirectories containing `default.nix` and returns their paths. Used throughout to auto-import modules without explicit listing.

### Hosts

Physical: `calanda` (APU router), `cyprianspitz` (APU1), `lindberg` (Asrock X570 main server)
VMs on lindberg: `lindberg-nextcloud`, `lindberg-build`, `lindberg-webapps`

Each host config in `nixos-configurations/<hostname>/` follows this structure:
`default.nix`, `networking.nix`, `filesystems.nix`, `backup.nix`, `secrets.nix`, plus `applications/` for service-specific config.

### Module Conventions

All custom options use the `qois.*` namespace (e.g., `qois.cloud`, `qois.git`, `qois.vpn-server`). Standard pattern:

```nix
options.qois.<service>.enable = mkEnableOption "description";
config = mkIf cfg.enable { /* ... */ };
```

### Secrets

Three tiers of SOPS-encrypted secrets in `private/`:

- `private/passwords.sops.yaml` — sysadmin passwords
- `private/nixos-modules/shared-secrets/default.sops.yaml` — shared across hosts
- `private/nixos-configurations/<hostname>/secrets.sops.yaml` — host-specific

### Deploy Profiles

- `system-vm` — virtual machines (timeout 300s/60s)
- `system-physical` — physical machines (timeout 600s/120s)
- `system-ci` — CI runners (deployed last to avoid breaking automation)

CI auto-deploys on `main` branch. Binary cache at `https://attic.qo.is/`.

### Network Topology

Physical networks: `plessur-ext/dmz/lan`, `riedbach-ext`, `lattenbach-ext/lan/nas`
Virtual: `backplane` overlay mesh, Headscale VPN on 100.64.0.0/10
Host metadata in `defaults/meta/` (`hosts.json`, `network-physical.nix`, `network-virtual.nix`).
