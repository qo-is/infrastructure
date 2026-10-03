# AGENTS.md

@CODESTYLE.md
@SUMMARY.md
@checks/README.md
@deploy/README.md
@README.md

## Commands

Commands not covered by the docs above:

```bash
nix develop                    # Enter dev shell (direnv auto-activates via .envrc); required before first commit, generates .pre-commit-config.yaml (important to run this in worktrees)

# In a fresh worktree: initialize the private submodule offline (a network clone hangs on askpass)
git submodule update --init --reference <main-checkout>/private

# Render the network diagrams (main.svg, network.svg), embedded into the docs
nix build .#topology.x86_64-linux.config.output
```

## Secrets

- Never read, decrypt, edit or commit anything in the `private/` submodule. Initializing it (see above) is the only exception; evaluating and building the flake is fine.
- If a change needs new or modified secrets, prompt the user with the exact commands to run (`sops <file>` with the keys to add, `sops-rekey` if needed, then the submodule commit and lock update from the README) and document the expected keys, e.g. in the PR description or the module README.

## Architecture

NixOS infrastructure-as-code repository (Nix Flakes). All services are defined declaratively as NixOS modules — no Docker, Terraform, or Pulumi.

### Flake Structure

`flake.nix` loads each output section from its subdirectory, passing a shared `importParams` record containing all flake inputs plus `pkgs`, `system`, and `deployPkgs`. Each subdirectory's `default.nix` receives these params.

```
flake.nix
├── checks/          → flake checks (builds, tests, formatting)
├── deploy/          → deploy-rs profiles
├── dev-shells/      → development shell with tools
├── nixos-configurations/  → per-host NixOS configs
├── nixos-modules/   → reusable NixOS modules
├── topology/        → nix-topology network diagrams rendered into the docs
├── packages/        → custom packages (auto-deploy, docs, sops wrapper)
├── lib/             → shared utilities
├── defaults/        → hardware profiles + network/host metadata
└── private/         → git submodule with SOPS-encrypted secrets
```

### Auto-Discovery

`lib/default.nix` provides `loadSubmodulesFrom(basePath)` which finds all subdirectories containing `default.nix` and returns their paths. Used throughout to auto-import modules without explicit listing.

### Hosts

Physical: `calanda` (APU router), `cyprianspitz` (Asrock Z790M), `lindberg` (Asrock X570 main server)
VMs on lindberg: `lindberg-nextcloud`, `lindberg-build`, `lindberg-webapps`

Each host config in `nixos-configurations/<hostname>/` follows this structure:
`default.nix`, `networking.nix`, `filesystems.nix`, `backup.nix`, `secrets.nix`, plus `applications/` for service-specific config.

### Module Conventions

All custom options use the `qois.*` namespace (e.g., `qois.cloud`, `qois.git`, `qois.vpn-server`). Standard pattern:

```nix
options.qois.<service>.enable = mkEnableOption "description";
config = mkIf cfg.enable { /* ... */ };
```

### Monitoring

Telegraf's SMART, mdstat, ZFS and disk inputs (and their default alert rules) come from the `inputs.srvos` `mixins-telegraf` module, not from `nixos-modules/telegraf`. Inspect them in the srvos source.

### Network Topology

Virtual: `backplane` overlay mesh, Headscale VPN.
Host metadata in `defaults/meta/` (`hosts.json`, `network-physical.nix`, `network-virtual.nix`).
