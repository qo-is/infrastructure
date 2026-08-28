{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    concatMapAttrs
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    ;
  inherit (lib.types)
    attrs
    attrsOf
    either
    listOf
    nonEmptyListOf
    package
    path
    port
    str
    submodule
    ;

  cfg = config.qois.kanidm;

  stateDir = "/var/lib/kanidm";
  tlsChain = "${stateDir}/fullchain.pem";
  tlsKey = "${stateDir}/key.pem";

  # Membership is curated interactively in the web UI, so provisioning must append
  # instead of replacing the member list on every run.
  appendedGroup = members: {
    inherit members;
    overwriteMembers = false;
  };

  roleGroupName = client: role: "${client}.${role}";
  accessGroupName = client: "${client}.access";

  clientGroups =
    client: clientCfg:
    {
      ${accessGroupName client} = appendedGroup (
        map (roleGroupName client) (builtins.attrNames clientCfg.roles)
      );
    }
    // mapAttrs' (
      role: _values: nameValuePair (roleGroupName client role) (appendedGroup [ ])
    ) clientCfg.roles;

  clientOauth2 =
    client: clientCfg:
    {
      inherit (clientCfg) displayName originUrl originLanding;
      basicSecretFile = clientCfg.secretFile;
      preferShortUsername = true;
      scopeMaps.${accessGroupName client} = clientCfg.scopes;
      claimMaps.${clientCfg.roleClaim}.valuesByGroup = mapAttrs' (
        role: values: nameValuePair (roleGroupName client role) values
      ) clientCfg.roles;
    }
    // clientCfg.extraSettings;

  # Read by kanidm as the owner and by the relying party as a group member.
  clientSecret = clientCfg: {
    owner = "kanidm";
    group = clientCfg.secretGroup;
    mode = "0440";
    restartUnits = [ "kanidm.service" ] ++ clientCfg.restartUnits;
  };

  installCert = pkgs.writeShellScript "kanidm-install-cert" ''
    ${pkgs.coreutils}/bin/install -o kanidm -g kanidm -m 0400 fullchain.pem ${tlsChain}
    ${pkgs.coreutils}/bin/install -o kanidm -g kanidm -m 0400 key.pem ${tlsKey}
  '';
in
{
  options.qois.kanidm = {
    enable = mkEnableOption "Enable qois identity management service";

    domain = mkOption {
      type = str;
      default = "id.qo.is";
      description = "Domain, under which the service is served.";
    };

    package = mkOption {
      type = package;
      default = pkgs.kanidmWithSecretProvisioning_1_11;
      description = "Kanidm package to use. Must support secret provisioning.";
    };

    port = mkOption {
      type = port;
      default = 8443;
      description = "Localhost port kanidm serves HTTPS on, behind nginx.";
    };

    ldapPort = mkOption {
      type = port;
      default = 636;
      description = ''
        Port of the LDAPS interface. No firewall port is opened for it, so it is only
        reachable from the host itself.
      '';
    };

    adminPasswordFile = mkOption {
      type = path;
      default = config.sops.secrets."kanidm/admin-password".path;
      defaultText = ''config.sops.secrets."kanidm/admin-password".path'';
      description = "Path to a file holding the password of the `admin` account.";
    };

    idmAdminPasswordFile = mkOption {
      type = path;
      default = config.sops.secrets."kanidm/idm-admin-password".path;
      defaultText = ''config.sops.secrets."kanidm/idm-admin-password".path'';
      description = "Path to a file holding the password of the `idm_admin` account.";
    };

    groups = mkOption {
      type = attrsOf (listOf str);
      default = {
        sysadmins = [ ];
      };
      description = ''
        Groups to provision, mapping a group name to its declared members. Members are
        appended, so additional members may be managed in the web UI.
      '';
    };

    oauth2Clients = mkOption {
      default = { };
      description = ''
        OAuth2 relying parties. For each client a `<name>.access` group and one
        `<name>.<role>` group per declared role are provisioned, and the basic secret is
        read from sops.
      '';
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              displayName = mkOption {
                type = str;
                description = "Name of the application as shown in the kanidm apps listing.";
              };

              originUrl = mkOption {
                type = either str (nonEmptyListOf str);
                description = "Redirect URL(s) of the application. Must match exactly.";
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
                description = "Scopes granted to members of the `<name>.access` group.";
              };

              roles = mkOption {
                type = attrsOf (listOf str);
                default = { };
                example = {
                  admins = [ "Admin" ];
                };
                description = ''
                  Maps a group name suffix to the claim values its members receive. Each entry
                  provisions a `<name>.<suffix>` group.
                '';
              };

              roleClaim = mkOption {
                type = str;
                default = "groups";
                description = "Name of the OIDC claim carrying the role values.";
              };

              secretFile = mkOption {
                type = path;
                default = config.sops.secrets."kanidm/oauth2/${name}".path;
                defaultText = ''config.sops.secrets."kanidm/oauth2/<name>".path'';
                description = "Path to a file holding the OAuth2 basic secret.";
              };

              secretGroup = mkOption {
                type = str;
                description = "Unix group of the relying party, granted read access to the secret.";
              };

              restartUnits = mkOption {
                type = listOf str;
                default = [ ];
                description = "Units of the relying party to restart when the secret changes.";
              };

              extraSettings = mkOption {
                type = attrs;
                default = { };
                description = "Additional `services.kanidm.provision.systems.oauth2.<name>` settings.";
              };
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    services.kanidm = {
      inherit (cfg) package;

      server = {
        enable = true;
        settings = {
          origin = "https://${cfg.domain}";
          inherit (cfg) domain;
          bindaddress = "[::1]:${toString cfg.port}";
          ldapbindaddress = "[::]:${toString cfg.ldapPort}";
          tls_chain = tlsChain;
          tls_key = tlsKey;
          http_client_address_info.x-forward-for = [ "::1" ];
          # Consistent database snapshots; copying the live sqlite file is not restore-safe.
          online_backup.versions = 7;
        };
      };

      client = {
        enable = true;
        settings.uri = "https://${cfg.domain}";
      };

      provision = {
        enable = true;
        inherit (cfg) adminPasswordFile idmAdminPasswordFile;

        groups =
          mapAttrs (_name: appendedGroup) cfg.groups // concatMapAttrs clientGroups cfg.oauth2Clients;

        systems.oauth2 = mapAttrs clientOauth2 cfg.oauth2Clients;
      };
    };

    sops.secrets = {
      "kanidm/admin-password".owner = "kanidm";
      "kanidm/idm-admin-password".owner = "kanidm";
    }
    // mapAttrs' (
      client: clientCfg: nameValuePair "kanidm/oauth2/${client}" (clientSecret clientCfg)
    ) cfg.oauth2Clients;

    # The certificate only appears once ACME has issued it for the first time, so kanidm
    # keeps retrying until nginx' certificate has been copied over.
    systemd.services.kanidm.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 60;
    };

    systemd.tmpfiles.settings."10-qois-kanidm".${stateDir}.d = {
      mode = "0700";
      user = "kanidm";
      group = "kanidm";
    };

    security.acme.certs.${cfg.domain} = {
      postRun = "${installCert}";
      reloadServices = [ "kanidm.service" ];
    };

    qois.backup-client.includePaths = [ stateDir ];

    services.telegraf.extraConfig.inputs.x509_cert = [
      { sources = [ "https://${cfg.domain}:443" ]; }
    ];

    networking.hosts."127.0.0.1" = [ cfg.domain ];
    services.nginx = {
      enable = true;

      virtualHosts.${cfg.domain} = {
        kTLS = true;
        forceSSL = true;
        enableACME = true;

        locations."/".proxyPass = "https://[::1]:${toString cfg.port}";
      };
    };
  };
}
