{ ... }:
{
  sops.secrets = {
    "gitlab-runner/default-registration" = {
      restartUnits = [ "gitlab-runner.service" ];
    };
  };
}
