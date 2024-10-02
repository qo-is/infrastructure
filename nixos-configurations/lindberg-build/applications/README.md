# Nix Caches

## Nixpkgs Cache

To put less load on the upstream nixpkgs CDN and speed up builds, we run a (public) nixpkgs cache on [nixpkgs-cache.qo.is](https://nixpkgs-cache.qo.is). To use it, configure nix like follows in your `nix.conf`:

```nix
substituters = https://nixpkgs-cache.qo.is?priority=39
```

Note that the [cache.nixos.org](https://cache.nixos.org) public key must also be trusted:

```nix
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

See the [nix documentation](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-substituters) for details about substitutors.

## Attic

We use [attic](https://docs.attic.rs/) as a self hosted nix build cache.

See [upstream documentation](https://docs.attic.rs/reference/attic-cli.html) for details on how to use it.

### Server Administration

Add users:

```bash
# For example, to generate a token for Alice with read-write access to any cache starting with `dev-` and read-only access to `prod`, expiring in 2 years:

atticadm make-token --sub "alice" --validity "2y" --pull "dev-*" --push "dev-*" --pull "prod"
```

### Client Usage

`attic login qois https://attic.qo.is <TOKEN_HERE>`

`attic use qois:cachename`
