# qo.is Infrastructure

[This repository](https://git.qo.is/qo.is/infrastructure) contains the infrastructure configuration and documentation sources.

Check out the current [rendered documentation](https://docs-ops.qo.is).

## Structure

`nixos-configurations`: Main nixos configuration for every host.\
`defaults`: Configuration defaults\
`nixos-modules`: Custom modules (e.g. for vpn and routers)\
`private`: Private configuration values (like users, sops-encrypted secrets and keys)

## Building

This repository requires [nix flakes](https://nixos.wiki/wiki/Flakes)

- `nix build`\
  Build all host configurations and docs
- `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel`\
  Build a single host configuration with
- `nix build .#docs`\
  Build the documentation website

## Development

- `nix develop`\
  Development environment
- `nix flake check`\
  Execute the project's checks
- `nix fmt`\
  Autofix formatting

### Working with the private submodule

To clone with submodules (if you have access):

```bash
git clone --recurse-submodules https://git.qo.is/qo.is/infrastructure.git
```

On changes:

```bash
git add private
nix flake lock --update-input private
```

## Deployment

`nix run .#deploy-qois`

See [Deployment](deploy/README.md) for details.

## Secrets

Secret management is done with [nix-sops](https://github.com/Mic92/sops-nix).

Secrets are stored in `private/passwords.sops.yaml` (sysadmin passwords),
`private/nixos-configurations/secrets.sops.yaml` (shared secrets for all hosts) and
`private/nixos-configurations/<hostname>/secrets.sops.yaml` (host specific secrets).

Usage:

```bash
sops $file # To edit a file
sops-rekey # To rekey all secrets, e.g. after a key rollover or new host
```

After changing secrets, don't forget to push the sub-repository and run
`nix flake update private` in the infrastructure repository to use the changes in builds.
