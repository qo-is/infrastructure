{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.qois.git-ci-runner;
  defaultInstanceName = "default";
in
with lib;
{
  options.qois.git-ci-runner = {
    enable = mkEnableOption "Enable qois git ci-runner service";

    domain = mkOption {
      type = types.str;
      default = "git.qo.is";
      description = "Domain, under which the service is served.";
    };
  };

  config = mkIf cfg.enable {

    sops.secrets."forgejo/runner-token/${defaultInstanceName}".restartUnits = [
      "gitea-runner-${defaultInstanceName}.service"
    ];

    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.${defaultInstanceName} = {
        enable = true;
        name = "${config.networking.hostName}-${defaultInstanceName}";
        url = "https://${cfg.domain}";
        tokenFile = config.sops.secrets."forgejo/runner-token/${defaultInstanceName}".path;
        labels = [
          "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
          "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
          "docker:docker://code.forgejo.org/oci/alpine:3.20"
        ];
        settings = {
          log.level = "warn";
          runner = {
            capacity = 30;
          };
          cache.enable = true; # TODO: This should probably be a central cache server?
        };
      };
    };
  };
}
