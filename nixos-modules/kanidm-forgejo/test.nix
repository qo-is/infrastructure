{ pkgs, ... }:
{ config, ... }:
let
  gitDomain = "git.${config.kanidmFixture.caDomain}";
in
{
  imports = [ ../kanidm-relying-party/test-fixture.nix ];

  kanidmFixture = {
    oauth2Secrets.forgejo = "snakeoilOauth2Secret";
    # Forgejo fetches kanidm's discovery document.
    pebbleCaClients = [ "forgejo" ];
  };

  args = { inherit gitDomain; };

  nodes.server =
    { config, ... }:
    {
      qois.git = {
        enable = true;
        domain = gitDomain;
      };
      qois.postgresql.package = pkgs.postgresql;

      qois.kanidm-forgejo.enable = true;

      environment.systemPackages = [ config.services.forgejo.package ];
    };
}
