inputs: {
  default =
    { config, pkgs, ... }:
    {

      imports = (inputs.self.lib.loadSubmodulesFrom ./.) ++ [ inputs.private.nixosModules.default ];
    };
}
