{ ... }:
let
  oauth2Secret = "snakeoilOauth2Secret";
in
{
  imports = [ ./test-fixture.nix ];

  kanidmFixture.oauth2Secrets.dummy = oauth2Secret;

  args = { inherit oauth2Secret; };

  nodes.server =
    { config, ... }:
    let
      party = config.qois.kanidm-relying-party.dummy;
    in
    {
      qois.kanidm-relying-party.dummy = {
        enable = true;
        displayName = "Dummy";
        originUrl = "https://dummy.test/oauth2/callback";
        originLanding = "https://dummy.test/";
        roles = {
          sysadmin = [ "admin" ];
          dummy-users = [ "user" ];
        };
        consumer = {
          enable = true;
          user = "dummy";
          group = "dummy";
        };
      };

      users.users.dummy = {
        isSystemUser = true;
        group = "dummy";
      };
      users.groups.dummy = { };

      # Stands in for the relying party: only succeeds if its secret copy is readable.
      systemd.services.dummy = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "dummy";
          Group = "dummy";
        };
        script = "test -s ${party.secretFiles.consumer}";
      };
    };
}
