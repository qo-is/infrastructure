{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    ;
  inherit (lib.types) str;
  cfg = config.qois.jellyfin;
in
{
  imports = [ inputs.nixflix.nixosModules.nixflix ];

  options.qois.jellyfin = {
    enable = mkEnableOption "Jellyfin media server via nixflix";
    domain = mkOption {
      type = str;
      default = "media.qo.is";
      description = "Base domain; jellyfin served at jellyfin.<domain>";
    };
  };

  config = mkIf cfg.enable {
    nixflix.enable = true;
    nixflix.jellyfin.enable = true;
    nixflix.jellyfin.subdomain = "jellyfin";
    nixflix.mediaDir = "/mnt/data/media";

    # Admin user: password is read at runtime from /run/jellyfin-admin-password,
    # which is materialized by jellyfin-credential-setup.service below.
    nixflix.jellyfin.users.admin = {
      password._secret = "/run/jellyfin-admin-password";
      policy.isAdministrator = true;
    };

    # Materializes admin password from systemd credential to a fixed path shared by
    # jellyfin-setup-wizard.service and jellyfin-users-config.service (both read
    # the same _secret path, but each has its own credential directory).
    # The container host passes the credential via --load-credential.
    # See nixos-configurations/lindberg/containers.nix.
    systemd.services.jellyfin-credential-setup = {
      description = "Materialize Jellyfin admin credential";
      before = [
        "jellyfin-setup-wizard.service"
        "jellyfin-users-config.service"
      ];
      requiredBy = [
        "jellyfin-setup-wizard.service"
        "jellyfin-users-config.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [ "jellyfin-admin-password:jellyfin-admin-password" ];
      };
      script = ''
        install -m 0400 "$CREDENTIALS_DIRECTORY/jellyfin-admin-password" /run/jellyfin-admin-password
      '';
    };

    # API key read from systemd credential passed by the container host via --load-credential.
    # Create: sops private/nixos-configurations/lindberg/secrets.sops.yaml
    #         add entry: jellyfin/apiKey: $(openssl rand -hex 16)
    nixflix.jellyfin.apiKey = {
      _secret = "/run/credentials/jellyfin-api-key.service/jellyfin-api-key";
    };
    systemd.services.jellyfin-api-key.serviceConfig.LoadCredential = [
      "jellyfin-api-key:jellyfin-api-key"
    ];

    # Reverse proxy via nixflix's nginx module: it builds the virtual host
    # "${subdomain}.${domain}" with proxyPass, websockets, buffering off, and
    # forceSSL via mkVirtualHost, and auto-derives knownProxies/localNetworkAddresses.
    # We layer per-host ACME (instead of nixflix's wildcard useACMEHost pattern) and kTLS on top.
    nixflix.nginx.enable = true;
    nixflix.nginx.domain = cfg.domain;
    nixflix.nginx.forceSSL = true;

    services.nginx.virtualHosts."jellyfin.${cfg.domain}" = {
      enableACME = true;
      kTLS = true;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
