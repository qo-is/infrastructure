# Git CI Runner

Runner for the [Forgejo git instance](../git/README.md).

## Default docker/ubuntu Runner

Registers a default runner with ubuntu OS or executes user's OCI container with podman.

## Nix runner

We provide a `runs-on: nix` runner which executes nix commands in a nix user environment on the build server.

Uses previously built derivations, which speeds up builds. Note that user-configured substitutors do not work (this is currently nix limitation of nix.)

⚠️ Builds use the system's nix-store in a unpriviledged mode, so derivations may be seen and used by other builds by this runner.
Consequentially, don't use to build nix things that should stay secret (which is a bad idea anyway).

## Create Secret Token

To create a new token for registration, follow the steps outlined in the [Forgejo documentation](https://forgejo.org/docs/latest/user/actions/#forgejo-runner).

## Clear Runner Caches

Under some circumstances, runner caches need to be cleared. This can be done with:

```bash
cd /var/lib/private/gitea-runner/
systemctl stop --all gitea-runner-*
rm -r */.cache/
systemctl start --all gitea-runner-*
```
