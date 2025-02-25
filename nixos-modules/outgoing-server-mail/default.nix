{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.qois.outgoing-server-mail;
in
with lib;
{
  options.qois.outgoing-server-mail = {
    enable = mkEnableOption ''Enable outgoing emails for server.'';
  };

  config = mkIf cfg.enable {

    sops.secrets."msmtp/password" = {
      owner = "root";
      group = config.users.groups.postdrop.name;
      mode = "0440";
    };

    users.groups.postdrop = { };

    programs.msmtp = {
      enable = true;
      defaults = {
        aliases = pkgs.writeText "aliases" ''
          root: sysadmin@qo.is
        '';
        port = 465;
        tls = true;
        tls_starttls = "off";

      };
      accounts.default = {
        auth = true;
        host = "mail.cyon.ch";
        user = "system@qo.is";
        from = "no-reply@qo.is";
        passwordeval = "${pkgs.coreutils}/bin/cat ${config.sops.secrets."msmtp/password".path}";
      };
    };
  };
}
