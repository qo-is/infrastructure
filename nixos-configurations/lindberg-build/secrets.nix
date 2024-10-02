{ ... }:
{
  sops.secrets = {
    "attic/server_token" = {
      restartUnits = [ "atticd.service" ];
    };
    "gitlab-runner/default-registration" = {
      restartUnits = [ "gitlab-runner.service" ];
    };
  };
}
