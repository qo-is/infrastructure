{
  self,
  nix-topology,
  pkgs,
  system,
  ...
}:
{
  ${system} = import nix-topology {
    # The renderer needs elk-to-svg, which only exists in the nix-topology overlay.
    pkgs = pkgs.extend nix-topology.overlays.default;
    modules = [
      ./networks.nix
      ./nodes.nix
      { inherit (self) nixosConfigurations; }
    ];
    # qois.meta comes from defaults/meta and is therefore identical on every host.
    specialArgs.qoisMeta = self.nixosConfigurations.calanda.config.qois.meta;
  };
}
