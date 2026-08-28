{
  config,
  lib,
  ...
}:

let
  cfg = config.qois.grafana;
  kanidm = config.qois.kanidm;

  # Group suffix in kanidm -> role value handed to grafana via the `groups` claim.
  oauthRoles = {
    editors = [ "Editor" ];
    admins = [ "Admin" ];
    server-admins = [ "GrafanaAdmin" ];
  };
  # JMESPath picking the most privileged role a person is entitled to.
  oauthRolePrecedence = [
    "GrafanaAdmin"
    "Admin"
    "Editor"
  ];
  oauthRoleAttributePath =
    lib.concatMapStrings (role: "contains(groups[*], '${role}') && '${role}' || ") oauthRolePrecedence
    + "'Viewer'";
in
with lib;
{
  options.qois.grafana = {
    enable = mkEnableOption "Enable grafana service";

    domain = mkOption {
      type = types.str;
      default = "monitoring.qo.is";
      description = "Domain, under which the service is served.";
    };

    bind_ip = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP to bind to";
    };

    port = lib.mkOption {
      type = types.port;
      default = 3000;
      description = "The port on which to serve grafana";
    };
  };

  config = mkIf cfg.enable {

    services.grafana = {
      enable = true;

      settings = {
        server = {
          root_url = "https://${cfg.domain}/";
          domain = cfg.domain;
          http_addr = cfg.bind_ip;
          http_port = cfg.port;

          enforce_domain = true;
          enable_gzip = true;
        };

        "auth.anonymous".enabled = false;

        security = {
          admin_user = "$__file{${config.sops.secrets."grafana/admin/user".path}}";
          admin_password = "$__file{${config.sops.secrets."grafana/admin/password".path}}";
          secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          disable_gravatar = true;
        };

        database = {
          type = "postgres";
          name = "grafana";
          host = "/run/postgresql";
          user = "grafana";
        };

        analytics = {
          reporting_enabled = false;
          feedback_links_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };

        provisioning = {
          repository_types = "git|local";
          allowed_git_urls = "git.qo.is";
        };
      };
    };

    sops.secrets =
      let
        user = config.users.users."grafana";
        grafanaSecret = {
          restartUnits = [ "grafana.service" ];
          owner = user.name;
          group = user.group;
        };
      in
      {
        "grafana/admin/user" = grafanaSecret;
        "grafana/admin/password" = grafanaSecret;
        "grafana/secret_key" = grafanaSecret;
      };

    services.postgresql =
      let
        name = config.users.users.grafana.name;
      in
      {
        enable = true;
        ensureUsers = [
          {
            inherit name;
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = [ name ];
      };

    services.grafana.provision.datasources.settings.datasources =
      optional config.services.prometheus.enable {
        name = "Prometheus";
        type = "prometheus";
        uid = "PBFA97CFB590B2093";
        url = "http://localhost:${toString config.services.prometheus.port}";
        isDefault = true;
        jsonData.timeInterval = "15s";
      }
      ++ optional config.services.loki.enable {
        name = "Loki";
        type = "loki";
        uid = "P8E80F9AEF21F6940";
        url = "http://localhost:${toString config.qois.loki.port}";
      };

    # Single sign-on through kanidm. The local admin account stays available as a fallback.
    qois.kanidm.oauth2Clients.grafana = mkIf kanidm.enable {
      displayName = "Grafana";
      originUrl = "https://${cfg.domain}/login/generic_oauth";
      originLanding = "https://${cfg.domain}/";
      roles = oauthRoles;
      secretGroup = config.users.users.grafana.group;
      restartUnits = [ "grafana.service" ];
    };

    services.grafana.settings."auth.generic_oauth" = mkIf kanidm.enable (
      let
        client = kanidm.oauth2Clients.grafana;
        origin = "https://${kanidm.domain}";
      in
      {
        enabled = true;
        name = kanidm.domain;
        client_id = "grafana";
        client_secret = "$__file{${client.secretFile}}";
        scopes = concatStringsSep " " client.scopes;

        auth_url = "${origin}/ui/oauth2";
        token_url = "${origin}/oauth2/token";
        api_url = "${origin}/oauth2/openid/grafana/userinfo";
        use_pkce = true;

        login_attribute_path = "preferred_username";
        role_attribute_path = oauthRoleAttributePath;
        role_attribute_strict = false;
        allow_assign_grafana_admin = true;
      }
    );

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

        locations."/" = {
          proxyPass = "http://${cfg.bind_ip}:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
