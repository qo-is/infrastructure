{
  config,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.qois.meta.hosts;
in
{
  options.qois.meta.hosts = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            hostName = mkOption {
              type = types.strMatching "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
              default = name;
              description = "The host's name. See networking.hostName for more details.";
            };

            sshKey = mkOption {
              type = types.nullOr (types.strMatching "^ssh-ed25519 [a-zA-Z0-9/+]{68}$");
              default = null;
              example = "ssh-ed25519 AAAAbcdefgh....xyz root@myhost";
              description = lib.mdDoc ''
                The ssh public key of ed25519 type.

                May be fetched with `ssh-keyscan example.com`.
              '';
            };
          };
        }
      )
    );
    default = { };
    description = "Host configuration properties options";
  };
  config =
    let
      hostsWithSshKey = lib.filterAttrs (_name: hostCfg: hostCfg.sshKey != null) cfg;
    in
    {
      programs.ssh.knownHosts = lib.mapAttrs (_name: hostCfg: {
        publicKey = hostCfg.sshKey;
      }) hostsWithSshKey;
    };
}
