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
        security.disable_initial_admin_creation = true;

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
            url = "http://localhost:${toString config.services.prometheus.port}";
            isDefault = true;
            jsonData.timeInterval = "15s";
          }
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
