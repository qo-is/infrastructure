{
  private,
  self,
  disko,
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
        sops-nix.nixosModules.sops
        private.nixosModules.default
      ];
    };
}
