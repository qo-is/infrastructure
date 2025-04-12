{
  deploy-rs,
  gitMinimal,
  writeShellApplication,
  lib,
  ...
}:
writeShellApplication {
  name = "auto-deploy";
  meta.description = "Deploy machines automatically.";
  runtimeInputs = [
    deploy-rs
    gitMinimal
  ];
  text = lib.readFile ./script.bash;
}
