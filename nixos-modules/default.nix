{
  private,
  self,
  disko,
  sops-nix,
  ...
}:
{
  default =
    { config, ... }:
    {

      imports = (self.lib.loadSubmodulesFrom ./.) ++ [
        ../defaults/meta
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        private.nixosModules.default
      ];

      qois.kanidm.secretsFile = "${private}/nixos-modules/kanidm/${config.networking.hostName}.sops.yaml";
    };
}
