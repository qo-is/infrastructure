# Updates

To update the infrastructure, do the following steps:

```bash

# Update inputs
nix flake update

# Check builds
nix build

# Push updates to git remote
git add flake.lock
git commit
git push
```

Deploy updates:

```bash
nix develop

# Deploy vms
auto-deploy system-vm

# Deploy CI hosts
auto-deploy system-ci

# Deploy physical hosts
auto-deploy system-physical


```

After deploying updates, verify that all services run as expected.
For kernel updates, it might be required to reboot machines, which can be done in parallel with e.g.:

```bash
pssh -l root -H lindberg-nextcloud.backplane.net.qo.is -H lindberg-build.backplane.net.qo.is reboot
```

## `systemVersion` upgrades

- Make sure to read through the nixpkgs changelog to catch configuration scheme changes,
  successor applications or for the need for manual interventions.
- Pay special attention the applications listed below.

## Application Updates

Some applications have pinned versions to prevent problems due to accidental upgrades.\
The version switch has to be done manually by switching the package used.

This includes the modules for:

- `nextcloud`
  - Check [admin panel](https://cloud.qo.is/settings/admin/overview) for warnings after upgrading
- `postgresql`, [→ Nixpkgs manual page](https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading)
