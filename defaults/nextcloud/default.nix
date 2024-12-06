# Default configuration for hosts
{
  config,
  lib,
  pkgs,
  ...
}:

{

  sops.secrets."nextcloud/admin" = with config.users.users.nextcloud; {
    inherit group;
    owner = name;
  };

  services.postgresql.enable = true;
  qois.backup-client.includePaths = [ config.services.nextcloud.home ];

  services.nextcloud = {
    enable = true;
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
        maps
        memories
        music
        news
        notes
        notify_push
        tasks
        twofactor_webauthn
        ;
    };

    phpOptions = {
      "opcache.interned_strings_buffer" = "23";
    };

    poolSettings = {
      "pm" = "dynamic";
      "pm.max_children" = "256";
      "pm.max_requests" = "500";
      "pm.max_spare_servers" = "16";
      "pm.min_spare_servers" = "2";
      "pm.start_servers" = "8";
    };

    configureRedis = true;
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
    };
  };

  services.phpfpm.pools.nextcloud.settings = {
    "pm.max_children" = lib.mkForce "256";
    "pm.max_spare_servers" = lib.mkForce "16";
    "pm.start_servers" = lib.mkForce "8";
  };

  users.users.nextcloud.extraGroups = [ "postdrop" ];

  systemd.services.nextcloud-cron = {
    path = [ pkgs.perl ];
  };

  environment.systemPackages = with pkgs; [
    nodejs # required for Recognize
  ];
}
