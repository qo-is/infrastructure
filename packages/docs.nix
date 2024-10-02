{ pkgs, self, ... }:
let
  version = self.rev or self.dirtyRev;
in
pkgs.stdenv.mkDerivation {
  inherit version;
  name = "qois-docs-${version}";
  buildInputs = with pkgs; [
    mdbook
    mdbook-cmdrun
    mdbook-plantuml
    plantuml
  ];
  src = ../.;
  buildPhase = "mdbook build --dest-dir $out";
}
