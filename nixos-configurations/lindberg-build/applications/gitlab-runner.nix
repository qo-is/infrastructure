{ config, pkgs, ... }:
{

  services.gitlab-runner = {
    enable = true;

    gracefulTimeout = "20min";

    clear-docker-cache = {
      enable = true;
      dates = "monthly";
    };

    services = {
      default = {
        runUntagged = true;
        # File should contain at least these two variables:
        # `CI_SERVER_URL`
        # `REGISTRATION_TOKEN`
        registrationConfigFile = config.sops.secrets."gitlab-runner/default-registration".path;
        dockerImage = "debian:stable";
        limit = 42; # The magic value
        maximumTimeout = 7200; # 2h oughta be enough for everyone
      };
    };
  };
}
