{
  deploy-rs,
  flakeSelf,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "deploy-qois";
  meta.description = "Deploy configuration to specificed targets.";
  runtimeInputs = [ deploy-rs ];
  text = ''
    deploy --remote-build --skip-checks --interactive --targets "''${@:-${flakeSelf}}"
  '';
}
