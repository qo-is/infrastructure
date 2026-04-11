{
  inputs,
  linkFarmFromDrvs,
  isFolderWithFile,
  getSubDirs,
  lib,
  testers,
  defaultModule,
}:
let
  inherit (lib)
    filter
    path
    mkDefault
    mkForce
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
    testers.runNixOSTest (
      { config, pkgs, ... }:
      {
        imports = [
          (import (getFilePath "test.nix") {
            inherit inputs;
            inherit name;
            inherit lib;
            inherit pkgs;
          })
        ];
        options = {
          args = lib.mkOption {
            description = "Additional arguments to pass to the test script";
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };
        };

        config = {
          inherit name;

          defaults = {
            imports = [ defaultModule ];

            qois.outgoing-server-mail.enable = mkForce false;
            qois.backup-client.enable = mkForce false;
          };

          # Calls a `test(...)` python function in the test's python file with the list of nodes and helper functions.
          # Helper symbols may be added as function args when needed and can be found in:
          #   https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/test-driver/src/test_driver/driver.py#L121
          testScript = mkDefault (
            { nodes, ... }:
            let
              script = readFile (getFilePath "test.py");
              # test nodes are passed as Python variable refs; config.args as string literals.
              nodeRefArgs = lib.genAttrs (attrNames nodes) lib.id;
              allArgs = nodeRefArgs // config.args;
              nodeArgs = concatStringsSep ", " (
                lib.mapAttrsToList (
                  k: v:
                  if nodeRefArgs ? ${k} && !(config.args ? ${k}) then
                    "${k}=${v}" # Python variable reference
                  else
                    ''${k}="${v}"'' # Python string literal
                ) allArgs
              );
            in
            ''
              ${script}
              test(${nodeArgs}, subtest=subtest)
            ''
          );
        };
      }
    );
in
pipe modulesBaseDir [
  getSubDirs
  (filter (isFolderWithFile "test.nix" modulesBaseDir))
  (map mkTest)
  (linkFarmFromDrvs "nixos-modules")
]
