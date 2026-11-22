# diff-closures

## Overview

Shell application that compares every nixosConfiguration closure between a base git ref and the current working tree.

## Interface

- Derivation `diff-closures`, description "Diff nixosConfiguration closures between two git refs." [default.nix:writeShellApplication]
- CLI: `diff-closures [base-ref]`, default `main` [script.bash:BASE_REF]
- Runtime deps: `dix`, `gitMinimal`, `jq` [default.nix:runtimeInputs]

## Invariants

- Configurations failing to build on either side are skipped with a `[SKIP]` message [script.bash:CONFIGS loop]
- Identical output paths are reported as "No changes."; otherwise `dix` prints the diff [script.bash:dix]

## Side Effects

- Creates a temporary git worktree at the base rev, initializes its submodules, and force-removes it on EXIT/INT/TERM [script.bash:BASE_WORKTREE, cleanup]
- Builds toplevel closures with `nix build --no-link` [script.bash:BASE_PATH, CUR_PATH]

## Verification

- Run: `nix build .#diff-closures`
