{
  mdbook-cmdrun,
  mdbook-plantuml,
  mdbook,
  plantuml,
  self,
  stdenv,
  ...
}:
let
  version = self.rev or self.dirtyRev;
in
stdenv.mkDerivation {
  inherit version;
  name = "qois-docs-${version}";
  buildInputs = [
    mdbook
    mdbook-cmdrun
    mdbook-plantuml
    plantuml
  ];
  src = self;
  buildPhase = "mdbook build --dest-dir $out";
}
