# Security Overrides

Use this module to deploy a security fix before it is in the stable channel (`nixpkgs` input).
The overrides apply to all hosts.

Each override takes the package from one pinned nixpkgs commit.
This commit is not a flake input, thus Renovate does not change it.

## Select the commit

1. Find the backport pull request of the fix to `release-26.05`.
   The [PR tracker](https://nixpk.gs/pr-tracker.html) shows which branches and channels have it.
1. Use the merge commit of the backport.
   If a channel (for example `nixos-26.05-small`) already has the fix, prefer the commit of that channel.
   Hydra built it, thus CI must build less.
1. Do not use a commit of `nixos-unstable`. The versions and dependencies are different from stable.
1. If the backport is not merged, apply the patch of the pull request with `overrideAttrs` on the stable package.

Get the hash of the commit:

```bash
nix flake prefetch github:NixOS/nixpkgs/<rev>
```

## Add an override

In `default.nix`, set the package option of the service with `securityOverride`.
Use the option of the service (for example `services.nginx.package`), not an overlay.
An overlay causes a rebuild of all packages that use the package.

```nix
services.nginx.package = securityOverride {
  stable = pkgs.nginxStable;
  override = (nixpkgsAt { rev = "<rev>"; narHash = "sha256-..."; }).nginxStable;
  fixedIn = "1.30.7";
  reason = "CVE-2026-XXXXX";
};
```

## Verify an override

```bash
# Evaluate. Expect the fixed version, no warning and no error.
nix eval --raw .#nixosConfigurations.lindberg.config.services.nginx.package.version

# Build the package only
nix build .#nixosConfigurations.lindberg.config.services.nginx.package --print-out-paths

# Run a VM test that uses the package
nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-grafana -L
```

Errors:

- `hash mismatch`: the `narHash` is wrong. The error shows the correct hash.
- `override has <version>, fix needs <fixedIn>`: the commit does not contain the fix.

After the deployment, examine the version on the host, for example `ssh root@<host> nginx -v`.

## Deploy

Build, push and deploy.
If it is urgent, deploy only the affected hosts (see [Deployment](../../deploy/README.md)).

## Remove an override

The evaluation shows a warning when the stable package version is `fixedIn` or higher.
Then remove the override.

If the fix is a patch without a version change, set `fixedIn = null`.
Then no check occurs. Remove the override manually when stable has the patch.
