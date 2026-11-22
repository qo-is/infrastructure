# docs

## Overview

Builds the mdBook documentation website, embedding the rendered network topology diagrams.

## Interface

- Derivation `qois-docs-<version>` via `stdenv.mkDerivation`; version is the flake `rev` or `dirtyRev` [default.nix:version]
- Build inputs: `mdbook`, `mdbook-cmdrun`, `mdbook-plantuml`, `plantuml` [default.nix:buildInputs]
- Sources: the whole flake source [default.nix:src]
- Consumed by [docs-ops deploy profile](../../deploy/docs-ops/EGM.md)

## Invariants

- Copies `main.svg` and `network.svg` from the topology output into `defaults/meta/` before the build [default.nix:buildPhase]
- Output is the `mdbook build` destination (`$out`) [default.nix:buildPhase]

## Side Effects

- None beyond the build sandbox

## Verification

- Run: `nix build .#docs`
