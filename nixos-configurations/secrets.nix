{ inputs, ... }:
{
  sops.secrets =
    let
      allHostsSecretsFile = "${inputs.private}/nixos-configurations/secrets.sops.yaml";
    in
    {
      "msmtp/password".sopsFile = allHostsSecretsFile;
      "wgautomesh/gossip-secret".sopsFile = allHostsSecretsFile;
    };
}
