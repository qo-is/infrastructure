# qo.is Infrastructure

[This repository](https://git.qo.is/qo.is/infrastructure) contains the infrastructure configuration and documentation sources.

Check out the current [rendered documentation](https://docs-ops.qo.is).

## Structure

`nixos-configurations`: Main nixos configuration for every host.\
`defaults`: Configuration defaults\
`nixos-modules`: Custom modules (e.g. for vpn and routers)\
`private`: Private configuration values (like users, sops-encrypted secrets and keys)

## Development

This repository requires [nix flakes](https://nixos.wiki/wiki/Flakes)

- `nix flake check`\
  Execute the project's checks, which includes building all configurations and packages. See [Tests](./checks/README.md).

- `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel`\
  Build a single host configuration.

- `nix build .#docs`\
  Build the documentation website.

- `nix develop`\
  Development environment

- `nix fmt`\
  Autofix formatting

### Secrets and `private` Submodule

Secret management is done with [nix-sops](https://github.com/Mic92/sops-nix) and a git submodule in `private`.\
Make sure you have the submodule correctly available. To clone with submodules (if you have access):

```bash
git clone --recurse-submodules https://git.qo.is/qo.is/infrastructure.git
# See below for how to commit changes.
```

Secrets are stored in `private/passwords.sops.yaml` (sysadmin passwords),
`private/nixos-modules/shared-secrets/default.sops.yaml` (shared secrets for all hosts) and
`private/nixos-configurations/<hostname>/secrets.sops.yaml` (host specific secrets).

To modify secrets:

```bash
sops $file # To edit a file
sops-rekey # To rekey all secrets, e.g. after a key rollover or new host
```

After changing secrets:

```bash
# Commit changes in subrepo
pushd private
  git commit
  git push
  nix flake prefetch . # Make subrepo available in nix store. Required until nix 2.27.
popd

git add private
nix flake lock --update-input private
```

## Deployment

See [Deployment](deploy/README.md) for details.
