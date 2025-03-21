{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.qois.renovate;
in
{

  options.qois.renovate = {
    enable = mkEnableOption "Enable renovate service";
    gitServer = mkOption {
      description = "Gitea/Forgejo server that should be accessed";
      type = types.str;
      default = "git.qo.is";
    };
    gitAuthor = mkOption {
      description = "Author of commit messages";
      type = types.str;
      default = "Renovate Bot <sysadmin+renovate@qo.is>";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."renovate/token".restartUnits = [ "renovate.service" ];
    sops.secrets."renovate/host_rules".restartUnits = [ "renovate.service" ];
    systemd.services.renovate.environment.LOG_LEVEL = "debug";
    services.renovate = {
      enable = true;
      credentials = {
        RENOVATE_TOKEN = config.sops.secrets."renovate/token".path;
        RENOVATE_HOST_RULES = config.sops.secrets."renovate/host_rules".path;
      };
      runtimePackages = with pkgs; [
        nix
      ];
      settings = {
        inherit (cfg) gitAuthor;
        endpoint = "https://${cfg.gitServer}/api/v1";
        platform = "gitea";
        autodiscover = true;
        optimizeForDisabled = true;
      };
      schedule = "*:0/10";
    };

    systemd.services.renovate = {
      path = mkBefore [ inputs.pkgs.nixVersions.git ]; # Circumvent submodule bug - remove after >=2.26 is the default.
      script = mkBefore ''
        echo -e "machine ${cfg.gitServer}\n    login $(systemd-creds cat 'SECRET-RENOVATE_TOKEN')\n    password x-oauth-basic" > ~/.netrc
      '';
    };
  };
}
