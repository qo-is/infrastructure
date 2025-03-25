{
  gnugrep,
  gnupg,
  lib,
  runCommand,
  private,
  ssh-to-age,
  writeText,
  ...
}:
with lib;
let
  metaHostConfigs = import ../../defaults/meta/hosts.nix { };
  userPgpKeys =
    let
      keysFolder = "${private}/sops_keys";
      gpgFingerprintsFile =
        runCommand "userPgpKeys"
          {
            src = keysFolder;
            buildInputs = [
              gnupg
              gnugrep
            ];
          }
          ''
            echo -n "[ " > $out
            for KEY in $src/*.asc; do
              FINGERPRINT=`
                gpg --homedir /tmp/.gnupg --with-colons --show-keys "$KEY" \
                  | grep ^fpr \
                  | grep --max-count 1 --only-matching --extended-regexp '[0-9A-Z]{40}' \
                  | cut -c -40
                `
              echo -n "\"$FINGERPRINT\" " >> $out
            done
            echo "]" >> $out
          '';
    in
    import "${gpgFingerprintsFile}";
  userAgeKeys = [ ];
  serverAgeKeys =
    let
      getHostsWithSshKeys = filterAttrs (name: cfg: cfg ? sshKey);
      mapHostToAgeKey = mapAttrs (
        name: cfg:
        readFile (
          runCommand "sshToAgeKey"
            {
              buildInputs = [ ssh-to-age ];
            }
            ''
              echo "${cfg.sshKey}" | ssh-to-age -o $out
            ''
        )
      );
    in
    mapHostToAgeKey (getHostsWithSshKeys metaHostConfigs.qois.meta.hosts);
  toCommaList = concatStringsSep ",";
in
writeText ".sops.yaml" (
  ''
    # This file was generated by nix, see packages/sops-config.nix for details.
  ''
  + strings.toJSON {
    keys = userPgpKeys ++ userAgeKeys ++ attrValues serverAgeKeys;
    creation_rules =
      [
        # Secrets for administrators (a.k.a. passwords)
        {
          path_regex = "private/passwords\.sops\.(yaml|json|env|ini)$";
          pgp = toCommaList userPgpKeys;
          age = toCommaList userAgeKeys;
        }

        # Secrets for all hosts
        {
          path_regex = "private/nixos-configurations/secrets\.sops\.(yaml|json|env|ini)$";
          pgp = toCommaList userPgpKeys;
          age = toCommaList (userAgeKeys ++ builtins.attrValues serverAgeKeys);
        }
      ]
      ++

      # Server specific secrets
      (mapAttrsToList (serverName: serverKey: {
        path_regex = "private/nixos-configurations/${serverName}/secrets\.sops\.(yaml|json|env|ini)$";
        pgp = toCommaList userPgpKeys;
        age = toCommaList (userAgeKeys ++ [ serverKey ]);
      }) serverAgeKeys);
  }
)
