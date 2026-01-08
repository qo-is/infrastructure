# Default configuration for hosts
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.qois.cloud;
in
with lib;
{

  options.qois.cloud = {
    enable = mkEnableOption "Enable qois cloud service";

    domain = mkOption {
      type = types.str;
      default = "cloud.qo.is";
      description = "Domain, under which the service is served.";
    };

    package = mkOption {
      type = types.package;
      description = "Which package to use for the Nextcloud instance.";
      relatedPackages = [
        "nextcloud28"
        "nextcloud29"
        "nextcloud30"
      ];
    };
  };

  config = mkIf cfg.enable {

    services.nginx.virtualHosts."${cfg.domain}" = {
      forceSSL = true;
      enableACME = true;
      kTLS = true;
    };

    sops.secrets."nextcloud/admin" = with config.users.users.nextcloud; {
      inherit group;
      owner = name;
    };

    services.postgresql.enable = true;
    qois.backup-client.includePaths = [ config.services.nextcloud.home ];

    services.nextcloud = {
      inherit (cfg) package;
      enable = true;
      hostName = cfg.domain;
      https = true;
      webfinger = true;
      maxUploadSize = "10G";

      database.createLocally = true;

      config = {
        adminpassFile = config.sops.secrets."nextcloud/admin".path;
        adminuser = "root";
        dbtype = "pgsql";
      };

      appstoreEnable = false;
      extraApps = {
        inherit (config.services.nextcloud.package.passthru.packages.apps)
          calendar
          contacts
          deck
          groupfolders
          # maps # Unsupported with nextcloud31, not widely used currently, so disable for now.
          memories
          music
          news
          notes
          tasks
          twofactor_webauthn
          ;
      };

      phpOptions = {
        "opcache.interned_strings_buffer" = "64";
        "opcache.memory_consumption" = "512";
        "opcache.save_comments" = "1";
        "opcache.max_accelerated_files" = "50000";
        "opcache.fast_shutdown" = "1";
        "opcache.jit" = "1255";
        "opcache.jit_buffer_size" = "8M";
      };

      poolSettings = {
        "pm" = "dynamic";
        "pm.max_children" = "480";
        "pm.max_requests" = "2000";
        "pm.max_spare_servers" = "72";
        "pm.min_spare_servers" = "24";
        "pm.start_servers" = "48";
      };

      caching.redis = true;

      notify_push = {
        enable = true;
        bendDomainToLocalhost = true;
      };

      settings = {
        log_type = "syslog";
        syslog_tag = "nextcloud";
        "memories.exiftool" = "${lib.getExe pkgs.exiftool}";
        "memories.vod.ffmpeg" = "${lib.getExe pkgs.ffmpeg-headless}";
        "memories.vod.ffprobe" = "${pkgs.ffmpeg-headless}/bin/ffprobe";
        preview_ffmpeg_path = "${lib.getExe pkgs.ffmpeg-headless}";
        mail_smtpmode = "sendmail";
        mail_domain = "qo.is";
        default_phone_region = "CH";
      };
    };

    users.users.nextcloud.extraGroups = [ "postdrop" ];

    systemd.services.nextcloud-cron = {
      path = [ pkgs.perl ];
    };

    environment.systemPackages = with pkgs; [
      nodejs # required for Recognize
    ];
  };
}
