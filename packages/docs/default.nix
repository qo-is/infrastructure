{
  mdbook-cmdrun,
  mdbook-plantuml,
  mdbook,
  plantuml,
  flakeSelfSpecialUsage,
  stdenv,
  system,
  ...
}:
let
  version = flakeSelfSpecialUsage.rev or flakeSelfSpecialUsage.dirtyRev;
  topologyDiagrams = flakeSelfSpecialUsage.topology.${system}.config.output;
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
  buildPhase = ''
    cp ${topologyDiagrams}/main.svg ${topologyDiagrams}/network.svg defaults/meta/
    mdbook build --dest-dir $out
  '';
}
