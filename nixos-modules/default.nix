{ private, self, ... }:
{
  default =
    { ... }:
    {

      imports = (self.lib.loadSubmodulesFrom ./.) ++ [ private.nixosModules.default ];
    };
}
