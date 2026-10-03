{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    ;
  inherit (lib.types)
    attrsOf
    listOf
    path
    str
    submodule
    ;

  cfg = config.qois.kanidm-relying-party;
  kanidm = config.qois.kanidm;
  sopsSecrets = config.sops.secrets;

  enabledParties = filterAttrs (_name: party: party.enable) cfg;
  consumingParties = filterAttrs (_name: party: party.consumer.enable) enabledParties;

  kanidmSecret = party: {
    key = party.secretKey;
    sopsFile = kanidm.secretsFile;
    owner = config.systemd.services.kanidm.serviceConfig.User;
    restartUnits = [ "kanidm.service" ];
  };

  consumerSecret = party: {
    key = party.secretKey;
    sopsFile = kanidm.secretsFile;
    owner = party.consumer.user;
    inherit (party.consumer) group;
    restartUnits = [ "${party.consumer.unit}.service" ];
  };

  kanidmClient = party: {
    inherit (party)
      displayName
      originUrl
      originLanding
      roles
      scopes
      ;
    secretFile = party.secretFiles.kanidm;
  };
in
{
  options.qois.kanidm-relying-party = mkOption {
    default = { };
    description = ''
      OAuth2 relying parties of kanidm. An entry is declared on the host running kanidm and
      on the host running the relying party; each side sets up its part, both decrypting the
      client secret from the shared `qois.kanidm.secretsFile`.
    '';
    type = attrsOf (
      submodule (
        { name, config, ... }:
        {
          options = {
            enable = mkEnableOption "the ${name} relying party";

            clientId = mkOption {
              type = str;
              default = name;
              description = "OAuth2 client identifier registered with kanidm.";
            };

            secretKey = mkOption {
              type = str;
              internal = true;
              readOnly = true;
              default = "kanidm/oauth2/${config.clientId}";
              description = "Key of the OAuth2 client secret in the shared sops file.";
            };

            displayName = mkOption {
              type = str;
              description = "Name of the application as shown in the kanidm apps listing.";
            };

            originUrl = mkOption {
              type = str;
              description = "Redirect URL of the relying party. Must match exactly.";
            };

            originLanding = mkOption {
              type = str;
              description = "Page to land on when opening the application from the apps listing.";
            };

            scopes = mkOption {
              type = listOf str;
              default = [
                "openid"
                "email"
                "profile"
              ];
              description = "Scopes the relying party requests and its users are granted.";
            };

            roles = mkOption {
              type = attrsOf (listOf str);
              default = { };
              description = ''
                Maps a kanidm group name to the values its members receive through the
                `groups` claim. The groups are provisioned and granted access to the client.
              '';
            };

            consumer = {
              enable = mkEnableOption "the relying party side on this host";

              unit = mkOption {
                type = str;
                default = name;
                description = "Name of the systemd service to restart when the secret changes.";
              };

              user = mkOption {
                type = str;
                description = "Owner of the relying party's copy of the secret.";
              };

              group = mkOption {
                type = str;
                description = "Group of the relying party's copy of the secret.";
              };
            };

            secretFiles = {
              kanidm = mkOption {
                type = path;
                default = sopsSecrets."${config.secretKey}/kanidm".path;
                defaultText = ''the path of the "kanidm/oauth2/<clientId>/kanidm" sops secret'';
                description = "Path to the client secret, readable by kanidm.";
              };

              consumer = mkOption {
                type = path;
                default = sopsSecrets."${config.secretKey}/${name}".path;
                defaultText = ''the path of the "kanidm/oauth2/<clientId>/<name>" sops secret'';
                description = "Path to the client secret, readable by `consumer.user`.";
              };
            };
          };
        }
      )
    );
  };

  config = {
    sops.secrets = mkMerge [
      (mkIf kanidm.enable (
        mapAttrs' (
          _name: party: nameValuePair "${party.secretKey}/kanidm" (kanidmSecret party)
        ) enabledParties
      ))
      (mapAttrs' (
        name: party: nameValuePair "${party.secretKey}/${name}" (consumerSecret party)
      ) consumingParties)
    ];

    qois.kanidm.oauth2Clients = mkIf kanidm.enable (
      mapAttrs' (_name: party: nameValuePair party.clientId (kanidmClient party)) enabledParties
    );
  };
}
