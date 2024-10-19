{
  gitMinimal,
  nix,
  sops,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "sops";
  meta.description = "Run SOPS with the generated configuration";
  runtimeInputs = [
    sops
    gitMinimal
    nix
  ];
  text = ''
    FLAKE_ROOT="$(git rev-parse --show-toplevel)"
    nix build --out-link "$FLAKE_ROOT/.sops.yaml" "$FLAKE_ROOT#sops-config"
    sops --config "''${FLAKE_ROOT}/.sops.yaml" "''${@}"
  '';
}
