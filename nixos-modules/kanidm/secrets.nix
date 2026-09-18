{
  config,
  inputs,
  ...
}:
{
  qois.kanidm.secretsFile = "${inputs.private}/nixos-modules/kanidm/${config.networking.hostName}.sops.yaml";
}
