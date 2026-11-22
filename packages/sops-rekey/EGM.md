# sops-rekey

## Overview

Runs `sops updatekeys` on every sops file below the current directory.

## Interface

- Derivation `sops-rekey`, description "Rekey all sops secrets with changed keys" [default.nix:writeShellApplication]
- CLI: no arguments; operates on `.` [default.nix:text]
- Runtime deps: `findutils`, `self.packages.${system}.sops` [default.nix:runtimeInputs]

## Invariants

- Matches files by the regex `.*\.sops\..*$` [default.nix:text]

## Side Effects

- Re-encrypts every matching file in place via `sops updatekeys --yes`, without confirmation prompts [default.nix:text]

## Verification

- Run: `nix build .#sops-rekey`
