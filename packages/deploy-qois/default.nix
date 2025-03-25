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
    deploy --interactive --targets "''${@:-${flakeSelf}}"
  '';
}
