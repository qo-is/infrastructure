{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) toJSON;
  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    getExe
    mkAfter
    mkEnableOption
    mkIf
    mkMerge
    ;
  inherit (pkgs)
    curl
    gawk
    writeShellApplication
    ;

  cfg = config.qois.kanidm-forgejo;
  party = config.qois.kanidm-relying-party.forgejo;
  kanidm = config.qois.kanidm;
  git = config.qois.git;
  forgejo = config.services.forgejo;

  # Name of the login source, part of the redirect URL.
  sourceName = "kanidm";
  adminGroup = "sysadmin";
  ownersGroup = "forgejo-qois";
  groupTeamMap.${ownersGroup}."qo.is" = [ "Owners" ];

  discoveryUrl = "https://${kanidm.domain}/oauth2/openid/${party.clientId}/.well-known/openid-configuration";

  # Forgejo has no declarative login sources; add or update it on every start.
  registerSource = writeShellApplication {
    name = "forgejo-register-kanidm";
    runtimeInputs = [
      curl
      gawk
      forgejo.package
    ];
    text = ''
      # Forgejo fetches the discovery document when the source is saved.
      curl --silent --show-error --fail --output /dev/null \
        --retry 15 --retry-delay 2 --retry-all-errors --max-time 10 \
        ${escapeShellArg discoveryUrl}

      id=$(forgejo admin auth list | awk '$2 == "${sourceName}" { print $1 }')

      args=(
        --name ${sourceName}
        --provider openidConnect
        --key ${escapeShellArg party.clientId}
        --secret "$(< ${party.secretFiles.consumer})"
        --auto-discover-url ${escapeShellArg discoveryUrl}
        ${concatMapStringsSep " " (scope: "--scopes ${escapeShellArg scope}") party.scopes}
        --group-claim-name groups
        --admin-group ${adminGroup}
        --group-team-map ${escapeShellArg (toJSON groupTeamMap)}
        --group-team-map-removal
        --skip-local-2fa
      )

      if [[ -n "$id" ]]; then
        forgejo admin auth update-oauth --id "$id" "''${args[@]}"
      else
        forgejo admin auth add-oauth "''${args[@]}"
      fi
    '';
  };
in
{
  options.qois.kanidm-forgejo.enable = mkEnableOption "forgejo single sign-on through kanidm";

  config = mkIf cfg.enable (mkMerge [
    {
      qois.kanidm-relying-party.forgejo = {
        enable = true;
        displayName = "Forgejo";
        originUrl = "https://${git.domain}/user/oauth2/${sourceName}/callback";
        originLanding = "https://${git.domain}/";
        roles = {
          ${adminGroup} = [ adminGroup ];
          forgejo-users = [ "forgejo-users" ];
          ${ownersGroup} = [ ownersGroup ];
        };
        consumer = {
          inherit (git) enable;
          unit = "forgejo";
          inherit (forgejo) user group;
        };
      };
    }

    (mkIf kanidm.enable {
      # Nested, so every sysadmin is an owner of the qo.is organisation.
      qois.kanidm.groups.${ownersGroup} = [ adminGroup ];

      systemd.services.forgejo.after = [
        "kanidm.service"
        "nginx.service"
      ];
    })

    (mkIf git.enable {
      services.forgejo.settings.oauth2_client = {
        ENABLE_AUTO_REGISTRATION = true;
        USERNAME = "preferred_username";
        # Links existing accounts by email. Only safe as long as persons cannot set their
        # own email address in kanidm.
        ACCOUNT_LINKING = "auto";
      };

      # Keep Forgejo available with the stored source if kanidm is unreachable.
      systemd.services.forgejo.preStart = mkAfter ''
        ${getExe registerSource} \
          || echo "warning: could not update the ${sourceName} login source" >&2
      '';
    })
  ]);
}
