# qo.is Infrastructure Blueprint

## System Overview

NixOS infrastructure-as-code for qo.is, built as a Nix flake. Human-facing documentation lives in [README.md](./README.md) and the mdBook index [SUMMARY.md](./SUMMARY.md); this file is the EGM contract index.

`flake.nix` imports each output from its subdirectory and passes it a layered input set to keep the dependency graph acyclic:

`checks -> (deploy, topology) -> nixosConfigurations -> (nixosModules, devShells) -> packages -> (lib, formatter)`

Each layer only sees the `self` outputs below it (`inputSubsetExternal`, `inputSubsetWithLibAndFormatter`, `inputSubsetWithPackages`, `inputSubsetForNixosModules`, `inputSubsetForNixosConfigurations`, `inputSubsetForDeploy`, `inputSubsetForChecks`). The only back edge is `packages.docs`, which reaches the topology through `flakeSelfSpecialUsage`.

Subdirectories are auto-discovered by `loadSubmodulesFrom` / `foldersWithNix` from [lib](./lib/EGM.md): any child directory with a `default.nix` is a module, host, package, check or deploy profile.

## Local Interface & Invariants

- Flake outputs `checks`, `deploy`, `topology`, `nixosConfigurations`, `nixosModules`, `devShells`, `packages`, `lib`, `formatter.x86_64-linux` [flake.nix:outputs]
- Inputs `nixpkgs` (nixos-26.05), `treefmt-nix`, `git-hooks-nix`, `sops-nix`, `srvos`, `nix-topology`, `deploy-rs`, `disko`, `private` (`git+file:./private`) [flake.nix:inputs]
- `system = "x86_64-linux"` only [flake.nix:system]
- `deployPkgs` overlays deploy-rs to use the nixpkgs `deploy-rs` binary with upstream `lib` [flake.nix:deployPkgs]
- Extra substituter `https://attic.qo.is/qois-infrastructure` [flake.nix:nixConfig]
- `formatter` is treefmt with nixfmt, deadnix, jsonfmt, yamlfmt, mdformat, ruff-check, ruff-format, shfmt; excludes `private`, `*.jpg`, `*.pdf`, `*.toml`, `nixos-modules/system/etc/*` [treefmt.nix:programs] [treefmt.nix:settings.global.excludes]
- Direct use of `self` inside imported outputs is avoided: `self` is replaced by a restricted set per layer [flake.nix:inputSubsetExternal]

## Subdirectories & System Boundaries

- checks: [./checks/EGM.md](./checks/EGM.md) - Flake checks: formatting, NixOS module VM tests, all host builds, topology, deploy-rs checks
- defaults: [./defaults/EGM.md](./defaults/EGM.md) - Hardware profiles and `qois.meta` host/network metadata
- deploy: [./deploy/EGM.md](./deploy/EGM.md) - deploy-rs profiles `system-ci`, `system-vm`, `system-physical` and `docs-ops.qo.is`
- dev-shells: [./dev-shells/EGM.md](./dev-shells/EGM.md) - Development shell with repo tools, treefmt pre-commit hook and generated `.sops.yaml`
- lib: [./lib/EGM.md](./lib/EGM.md) - Subdirectory auto-discovery helpers (`getSubDirs`, `isFolderWithFile`, `foldersWithNix`, `loadSubmodulesFrom`)
- nixos-configurations: [./nixos-configurations/EGM.md](./nixos-configurations/EGM.md) - One `nixosSystem` per host: calanda, cyprianspitz, lindberg and the lindberg VMs (build, nextcloud, webapps)
- nixos-modules: [./nixos-modules/EGM.md](./nixos-modules/EGM.md) - Reusable `qois.*` NixOS modules, exported as `nixosModules.default`
- packages: [./packages/EGM.md](./packages/EGM.md) - Operational tools (auto-deploy, diff-closures, sops wrappers, disk unlock, grafana-mcp) and the docs site
- topology: [./topology/EGM.md](./topology/EGM.md) - nix-topology network diagrams rendered into the docs
- private: git submodule with SOPS-encrypted secrets (not documented here)

## Global Invariants

- All custom options live under the `qois.*` namespace; modules are enabled per host via `qois.<service>.enable`
- Secrets are only referenced by sops secret name; values live in the `private` submodule
- Deploy category is derived from host config: `system-ci` if `qois.git-ci-runner.enable`, else `system-vm` if `services.qemuGuest.enable`, else `system-physical` (see [deploy](./deploy/EGM.md))
- Hosts and networks are described once in `qois.meta` ([defaults/meta](./defaults/meta/EGM.md)) and consumed by backplane, loadbalancer, DNS, topology and sops config

## Global Side Effects

- Deployment over SSH as root to hosts reachable via the backplane overlay or the Headscale VPN
- Hosts share the `backplane` WireGuard mesh, central Prometheus/Loki/Alertmanager on lindberg-webapps, and Borg backups to backup servers
- Outgoing mail via mail.cyon.ch, ACME certificates for public virtual hosts

## System Verification

- Run: `nix flake check`
- Format: `nix fmt`
- Single host: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
