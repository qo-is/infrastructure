{
  dix,
  gitMinimal,
  jq,
  lib,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "diff-closures";
  meta.description = "Diff nixosConfiguration closures between two git refs.";
  runtimeInputs = [
    dix
    gitMinimal
    jq
  ];
  text = lib.readFile ./script.bash;
}
