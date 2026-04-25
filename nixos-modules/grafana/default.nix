{
  config,
  lib,
  ...
}:

let
  cfg = config.qois.grafana;
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
        };
      };

      provision.dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "default";
            type = "file";
            options.path = "/etc/grafana/dashboards";
          }
        ];
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
      lib.mkIf config.services.prometheus.enable
        [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "PBFA97CFB590B2093";
            url = "http://localhost:${toString config.services.prometheus.port}";
            isDefault = true;
            jsonData.timeInterval = "15s";
          }
        ];

    environment.etc."grafana/dashboards/overview.json".source = ./dashboards/overview.json;

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
