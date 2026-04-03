{
  private,
  self,
  disko,
  microvm,
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
        microvm.nixosModules.host
        sops-nix.nixosModules.sops
        private.nixosModules.default
      ];
    };
}
