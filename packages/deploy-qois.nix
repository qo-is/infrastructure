{
  pkgs,
  self,
  system,
  ...
}:
pkgs.writeShellApplication {
  name = "deploy-qois";
  meta.description = "Deploy configuration to specificed targets.";
  runtimeInputs = [ pkgs.deploy-rs ];
  text = ''
    deploy --interactive --targets "''${@:-${self}}"
  '';
}
