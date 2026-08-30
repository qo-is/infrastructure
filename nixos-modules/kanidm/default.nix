{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    attrNames
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkMerge
    mkOption
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

  stateDir = builtins.dirOf config.services.kanidm.server.settings.db_path;
  tlsChain = "${stateDir}/fullchain.pem";
  tlsKey = "${stateDir}/key.pem";

  # Membership is curated interactively in the web UI, so provisioning must append
  # instead of replacing the member list on every run.
  appendedGroup = members: {
    inherit members;
    overwriteMembers = false;
  };

  accessGroupName = client: "${client}.access";

  clientGroups =
    client: clientCfg:
    {
      ${accessGroupName client} = appendedGroup (attrNames clientCfg.roles);
    }
    // mapAttrs (_role: _values: appendedGroup [ ]) clientCfg.roles;

  clientOauth2 =
    client: clientCfg:
    {
      inherit (clientCfg) displayName originUrl originLanding;
      basicSecretFile = clientCfg.secretFile;
      preferShortUsername = true;
      scopeMaps.${accessGroupName client} = clientCfg.scopes;
      claimMaps.${clientCfg.roleClaim}.valuesByGroup = clientCfg.roles;
    }
    // clientCfg.settings;
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
      description = "Port of the LDAPS interface.";
    };

    secretsFile = mkOption {
      type = path;
      description = ''
        sops file holding the secrets kanidm shares with its relying parties. It is
        encrypted for the host it belongs to and for the host running kanidm.
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
        sysadmin = [ ];
      };
      description = ''
        Groups to provision, mapping a group name to its declared members. Members are
        appended, so additional members may be managed in the web UI.
      '';
    };

    oauth2Clients = mkOption {
      default = { };
      description = ''
        OAuth2 relying parties. For each client a `<name>.access` group is provisioned,
        holding the groups its roles are mapped to.
      '';
      type = attrsOf (submodule {
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
              sysadmin = [ "Admin" ];
            };
            description = ''
              Maps a group name to the claim values its members receive. The groups are
              provisioned and granted access to the client.
            '';
          };

          roleClaim = mkOption {
            type = str;
            default = "groups";
            description = "Name of the OIDC claim carrying the role values.";
          };

          secretFile = mkOption {
            type = path;
            description = ''
              Path to a file holding the OAuth2 basic secret, readable by kanidm. It is
              declared by whoever declares the client.
            '';
          };

          settings = mkOption {
            type = attrs;
            default = { };
            description = "Additional `services.kanidm.provision.systems.oauth2.<name>` settings.";
          };
        };
      });
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
          # Restore-safe snapshots for borg to pick up; borg keeps the history.
          online_backup.versions = 2;
        };
      };

      client = {
        enable = true;
        settings.uri = "https://${cfg.domain}";
      };

      provision = {
        enable = true;
        inherit (cfg) adminPasswordFile idmAdminPasswordFile;

        groups = mkMerge (
          [ (mapAttrs (_name: appendedGroup) cfg.groups) ] ++ mapAttrsToList clientGroups cfg.oauth2Clients
        );

        systems.oauth2 = mapAttrs clientOauth2 cfg.oauth2Clients;
      };
    };

    sops.secrets = {
      "kanidm/admin-password".owner = "kanidm";
      "kanidm/idm-admin-password".owner = "kanidm";
    };

    # postRun of this unit installs the certificate kanidm needs to start.
    systemd.services.kanidm = {
      after = [ "acme-order-renew-${cfg.domain}.service" ];
      wants = [ "acme-order-renew-${cfg.domain}.service" ];
    };

    security.acme.certs.${cfg.domain} = {
      postRun =
        let
          inherit (config.systemd.services.kanidm.serviceConfig) User Group;
        in
        ''
          # Runs before kanidm's first start, so systemd has not created StateDirectory yet.
          install -d -o ${User} -g ${Group} -m 0700 ${stateDir}
          install -o ${User} -g ${Group} -m 0400 fullchain.pem ${tlsChain}
          install -o ${User} -g ${Group} -m 0400 key.pem ${tlsKey}
        '';
      reloadServices = [ "kanidm.service" ];
    };

    qois.backup-client.includePaths = [ stateDir ];

    qois.telegraf.serviceInputs = {
      http_response = [
        {
          urls = [ "https://${cfg.domain}/status" ];
          response_string_match = "true";
        }
      ];
      x509_cert = [
        { sources = [ "https://${cfg.domain}:443" ]; }
      ];
    };

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
