{
  pkgs,
  self,
  ...
}@params:
let
  inherit (pkgs.lib) foldl pipe recursiveUpdate;
in
pipe ./. [
  self.lib.loadSubmodulesFrom
  (map (f: (import f params)))
  (foldl recursiveUpdate { })
]
