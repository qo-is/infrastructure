{
  mdbook-cmdrun,
  mdbook-plantuml,
  mdbook,
  plantuml,
  flakeSelfSpecialUsage,
  stdenv,
  ...
}:
let
  version = flakeSelfSpecialUsage.rev or flakeSelfSpecialUsage.dirtyRev;
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
  src = flakeSelfSpecialUsage;
  buildPhase = "mdbook build --dest-dir $out";
}
