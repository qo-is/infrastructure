{ system, ... }@inputs:
{
  ${system} =
    let
      all = import ./all.nix inputs;
    in
    {
      inherit all;
      default = all;
      cache = import ./cache.nix inputs;
      deploy-qois = import ./deploy-qois.nix inputs;
      docs = import ./docs.nix inputs;
      sops = import ./sops.nix inputs;
      sops-config = import ./sops-config.nix inputs;
      sops-rekey = import ./sops-rekey.nix inputs;
    };
}
