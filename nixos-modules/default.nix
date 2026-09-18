{
  private,
  self,
  disko,
  nix-topology,
  sops-nix,
  ...
}:
{
  default =
    { ... }:
    {

      imports = (self.lib.loadSubmodulesFrom ./.) ++ [
        ../defaults/meta
        disko.nixosModules.disko
        nix-topology.nixosModules.default
        sops-nix.nixosModules.sops
        private.nixosModules.default
      ];
    };
}
