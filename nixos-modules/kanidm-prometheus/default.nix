{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mkEnableOption
    mkIf
    mkMerge
    optionalAttrs
    ;

  cfg = config.qois.kanidm-prometheus;
  party = config.qois.kanidm-relying-party.prometheus;
  kanidm = config.qois.kanidm;
  prometheus = config.services.prometheus;
  inherit (config.qois.prometheus) domain;
  oauth2ProxyUser = config.users.users.oauth2-proxy;
  accessRole = "PrometheusAdmin";
  loopback = "127.0.0.1";

  # Not `proxyPass`: with proxyResolveWhileRunning it reads $nix_proxy_target, which the
  # auth_request subrequest to /oauth2/auth overwrites with the oauth2-proxy URL.
  proxyTo = port: "proxy_pass http://${loopback}:${toString port};";
in
{
  options.qois.kanidm-prometheus.enable = mkEnableOption "the prometheus and alertmanager web UIs behind kanidm single sign-on";

  config = mkIf cfg.enable (mkMerge [
    {
      qois.kanidm-relying-party.prometheus = {
        enable = true;
        displayName = "Prometheus";
        originUrl = "https://${domain}/oauth2/callback";
        originLanding = "https://${domain}/";
        roles.sysadmin = [ accessRole ];
        consumer = {
          inherit (prometheus) enable;
          unit = "oauth2-proxy";
          user = oauth2ProxyUser.name;
          inherit (oauth2ProxyUser) group;
        };
      };
    }

    (mkIf kanidm.enable {
      systemd.services.oauth2-proxy = {
        after = [
          "kanidm.service"
          "nginx.service"
        ];
        wants = [ "kanidm.service" ];
      };
    })

    (mkIf prometheus.enable {
      services.oauth2-proxy = {
        enable = true;
        provider = "oidc";
        clientID = party.clientId;
        clientSecretFile = party.secretFiles.consumer;
        oidcIssuerUrl = "https://${kanidm.domain}/oauth2/openid/${party.clientId}";
        redirectURL = "https://${domain}/oauth2/callback";
        scope = concatStringsSep " " party.scopes;
        approvalPrompt = "auto";
        email.domains = [ "*" ];
        reverseProxy = true;
        trustedProxyIP = [
          "${loopback}/32"
          "::1/128"
        ];
        cookie = {
          secretFile = config.sops.secrets."oauth2-proxy/cookie-secret".path;
          expire = "24h";
        };
        extraConfig = {
          code-challenge-method = "S256";
          cookie-samesite = "lax";
          whitelist-domain = [ domain ];
        };
        nginx = {
          inherit domain;
          virtualHosts.${domain}.allowed_groups = [ accessRole ];
        };
      };

      # OIDC discovery fails until kanidm and nginx serve the issuer.
      systemd.services.oauth2-proxy = {
        serviceConfig.RestartSec = "5s";
        unitConfig.StartLimitIntervalSec = 0;
      };

      sops.secrets."oauth2-proxy/cookie-secret".restartUnits = [ "oauth2-proxy.service" ];

      networking.hosts.${loopback} = [ domain ];

      services.nginx = {
        enable = true;
        virtualHosts.${domain} = {
          kTLS = true;
          forceSSL = true;
          enableACME = true;
          locations = {
            "/".extraConfig = proxyTo prometheus.port;
          }
          // optionalAttrs prometheus.alertmanager.enable {
            "/alertmanager/".extraConfig = proxyTo prometheus.alertmanager.port;
          };
        };
      };

      qois.telegraf.serviceInputs.x509_cert = [
        { sources = [ "https://${domain}:443" ]; }
      ];
    })
  ]);
}
