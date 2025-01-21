{
  config,
  pkgs,
  lib,
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
    services.renovate = {
      enable = true;
      credentials.RENOVATE_TOKEN = config.sops.secrets."renovate/token".path;
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
  };
}
