{
  linkFarmFromDrvs,
  isFolderWithFile,
  getSubDirs,
  lib,
  testers,
}:
let
  inherit (lib)
    filter
    path
    mkDefault
    readFile
    attrNames
    concatStringsSep
    pipe
    ;
  modulesBaseDir = ../../nixos-modules;
  mkTest =
    name:
    let
      getFilePath = file: path.append modulesBaseDir "./${name}/${file}";
    in
    testers.runNixOSTest {
      inherit name;
      imports = [
        (import (getFilePath "test.nix") {
          inherit name;
          inherit lib;
        })
      ];

      defaults.imports = [ (getFilePath "default.nix") ];

      # Calls a `test(...)` python function in the test's python file with the list of nodes and helper functions.
      # Helper symbols may be added as function args when needed and can be found in:
      #   https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/test-driver/src/test_driver/driver.py#L121
      testScript = mkDefault (
        { nodes, ... }:
        let
          script = readFile (getFilePath "test.py");
          nodeArgs = pipe nodes [
            attrNames
            (map (val: "${val}=${val}"))
            (concatStringsSep ", ")
          ];
        in
        ''
          ${script}
          test(${nodeArgs}, subtest=subtest)
        ''
      );
    };
in
pipe modulesBaseDir [
  getSubDirs
  (filter (isFolderWithFile "test.nix" modulesBaseDir))
  (map mkTest)
  (linkFarmFromDrvs "nixos-modules")
]
