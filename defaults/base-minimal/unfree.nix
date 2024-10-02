{
  config,
  lib,
  pkgs,
  ...
}:

{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "corefonts"
      "camingo-code"
      "helvetica-neue-lt-std"
      #"kochi-substitute-naga10"
      "ttf-envy-code-r"
      "vista-fonts"
      "vista-fonts-chs"
      "xkcd-font-unstable"
      "ricty"
    ];
}
