#!/usr/bin/env bash
# Usage: diff-closures [base-ref]
# Compares nixosConfiguration closures between base-ref and the current working tree.
# Defaults: base=main

BASE_REF="${1:-main}"

FLAKE_ROOT="$(git rev-parse --show-toplevel)"
BASE_REV="$(git rev-parse "$BASE_REF")"

echo "Comparing nixosConfigurations: ${BASE_REF} (${BASE_REV:0:8}) → current tree"

# Enumerate nixosConfigurations from current flake
CONFIGS=$(nix eval --json "${FLAKE_ROOT}#nixosConfigurations" --apply 'builtins.attrNames' | jq -r '.[]')

# Create worktree for base ref
BASE_WORKTREE=$(mktemp -d)
cleanup() {
  git -C "${FLAKE_ROOT}" worktree remove --force "${BASE_WORKTREE}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

git -C "${FLAKE_ROOT}" worktree add "${BASE_WORKTREE}" "${BASE_REV}"
git -C "${BASE_WORKTREE}" submodule update --init

for CONFIG in $CONFIGS; do
  echo ""
  echo "════════════════════════════════════════"
  echo "  ${CONFIG}"
  echo "════════════════════════════════════════"

  BASE_PATH=$(nix build --no-link --print-out-paths \
    "${BASE_WORKTREE}#nixosConfigurations.${CONFIG}.config.system.build.toplevel" 2>/dev/null) || {
    echo "  [SKIP] Failed to build ${CONFIG} on ${BASE_REF}"
    continue
  }

  CUR_PATH=$(nix build --no-link --print-out-paths \
    "${FLAKE_ROOT}#nixosConfigurations.${CONFIG}.config.system.build.toplevel" 2>/dev/null) || {
    echo "  [SKIP] Failed to build ${CONFIG} on current branch"
    continue
  }

  if [ "${BASE_PATH}" = "${CUR_PATH}" ]; then
    echo "  No changes."
  else
    dix "${BASE_PATH}" "${CUR_PATH}"
  fi
done
