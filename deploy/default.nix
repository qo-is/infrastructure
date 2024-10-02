{
  deployPkgs,
  pkgs,
  self,
  ...
}@params:
with pkgs.lib;
pipe ./. [
  self.lib.loadSubmodulesFrom
  (map (f: (import f params)))
  (foldl recursiveUpdate { })
]
