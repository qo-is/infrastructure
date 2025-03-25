{
  mdbook-cmdrun,
  mdbook-plantuml,
  mdbook,
  plantuml,
  flakeSelf,
  stdenv,
  ...
}:
let
  version = flakeSelf.rev or flakeSelf.dirtyRev;
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
  src = flakeSelf;
  buildPhase = "mdbook build --dest-dir $out";
}
