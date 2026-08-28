{
  lib,
  ...
}:
let
  inherit (lib) mkOption;
  inherit (lib.types) path;
in
{
  options.qois.sharedSecretsFile = mkOption {
    type = path;
    description = ''
      sops file from the private submodule holding secrets shared across all hosts.
      Modules that need a secret on more than one host set it as the `sopsFile` of their
      `sops.secrets` entry.
    '';
  };
}
