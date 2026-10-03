# Shared setup for tests of kanidm relying parties: pebble, and a server node running kanidm
# with real sops secrets. Import it into a test and set the `kanidmFixture` options.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) toJSON;
  inherit (lib)
    genAttrs
    mkForce
    mkOption
    recursiveUpdate
    stringAfter
    ;
  inherit (lib.types)
    attrs
    attrsOf
    listOf
    str
    ;
  inherit (pkgs)
    age
    curl
    gnugrep
    kanidmWithSecretProvisioning_1_11
    runCommand
    sops
    util-linux
    writeShellApplication
    writeText
    ;

  cfg = config.kanidmFixture;
  certs = import "${pkgs.path}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  kanidmPackage = kanidmWithSecretProvisioning_1_11;
  ageKeyFile = "/var/lib/sops-nix/key.txt";
  idmAdminPassword = "snakeoilIdmAdminPassword";

  sharedSecrets = [
    "msmtp/password"
    "wgautomesh/gossip-secret"
  ];

  plaintext = recursiveUpdate {
    msmtp.password = "unused";
    wgautomesh.gossip-secret = "unused";
    kanidm = {
      admin-password = "snakeoilAdminPassword";
      idm-admin-password = idmAdminPassword;
      oauth2 = cfg.oauth2Secrets;
    };
  } cfg.secrets;

  sopsSecrets =
    runCommand "kanidm-relying-party-test-secrets"
      {
        nativeBuildInputs = [
          age
          sops
        ];
      }
      ''
        mkdir $out
        age-keygen -o $out/age-key.txt
        sops encrypt --age "$(age-keygen -y $out/age-key.txt)" \
          --input-type json --output-type yaml \
          ${writeText "secrets.json" (toJSON plaintext)} > $out/secrets.yaml
      '';

  # Creates a person with a password and the given groups.
  testPerson = writeShellApplication {
    name = "kanidm-test-person";
    runtimeInputs = [
      kanidmPackage
      util-linux
    ];
    text = ''
      name=$1
      password=$2
      shift 2

      export KANIDM_URL=https://localhost:8443 KANIDM_ACCEPT_INVALID_CERTS=true
      KANIDM_PASSWORD=${idmAdminPassword} kanidm login --name idm_admin
      # Persons need MFA by default.
      kanidm group account-policy credential-type-minimum idm_all_persons any --name idm_admin

      kanidm person create "$name" "$name" --name idm_admin
      kanidm person update "$name" --mail "$name@${cfg.caDomain}" --name idm_admin
      for group in "$@"; do
        kanidm group add-members "$group" "$name" --name idm_admin
      done

      KANIDM_RECOVER_ACCOUNT_PASSWORD=$password runuser -u kanidm -- \
        kanidmd scripting recover-account -c /etc/kanidm/server.toml "$name" --from-environment \
        > /dev/null
    '';
  };

  # Logs in at a relying party through kanidm's login and consent forms; prints the URL it
  # lands on.
  oidcLogin = writeShellApplication {
    name = "kanidm-oidc-login";
    runtimeInputs = [
      curl
      gnugrep
    ];
    text = ''
      start=$1
      username=$2
      password=$3
      jar=$4
      kanidm=https://${cfg.kanidmDomain}
      page=$(mktemp)

      request() {
        curl --silent --show-error --fail --location --cacert ${cfg.caFile} \
          --cookie "$jar" --cookie-jar "$jar" --output "$page" \
          --write-out '%{url_effective}' "$@"
      }

      request "$start" > /dev/null
      request --data-urlencode "username=$username" "$kanidm/ui/login/begin" > /dev/null
      url=$(request --data-urlencode "password=$password" "$kanidm/ui/login/pw")

      token=$(grep -oP 'name="consent_token" value="\K[^"]+' "$page" || true)
      if [[ -n "$token" ]]; then
        url=$(request --data-urlencode "consent_token=$token" "$kanidm/ui/oauth2/consent")
      fi

      echo "$url"
    '';
  };
in
{
  options.kanidmFixture = {
    oauth2Secrets = mkOption {
      type = attrsOf str;
      description = "Client secret per OAuth2 client id.";
    };
    secrets = mkOption {
      type = attrs;
      default = { };
      description = "Further plaintext content of the sops file, e.g. secrets of the relying party.";
    };
    pebbleCaClients = mkOption {
      type = listOf str;
      default = [ ];
      description = "Services on the server that have to trust pebble's CA, e.g. to reach kanidm.";
    };
    caDomain = mkOption {
      type = str;
      readOnly = true;
      default = certs.domain;
    };
    kanidmDomain = mkOption {
      type = str;
      readOnly = true;
      default = "id.${cfg.caDomain}";
    };
    caFile = mkOption {
      type = str;
      readOnly = true;
      default = "/run/pebble-ca.crt";
    };
  };

  config = {
    args = {
      inherit (cfg) caDomain caFile kanidmDomain;
      inherit idmAdminPassword;
    };

    nodes = {
      acme = {
        imports = [ "${pkgs.path}/nixos/tests/common/acme/server" ];
      };

      server =
        { config, ... }:
        {
          security.pki.certificateFiles = [ certs.ca.cert ];
          security.acme.defaults.server = "https://${cfg.caDomain}/dir";

          sops = {
            defaultSopsFile = "${sopsSecrets}/secrets.yaml";
            # The file is built, so evaluation cannot read it.
            validateSopsFiles = false;
            age = {
              keyFile = ageKeyFile;
              sshKeyPaths = mkForce [ ];
            };
            gnupg.sshKeyPaths = mkForce [ ];
            secrets = genAttrs sharedSecrets (_name: {
              sopsFile = mkForce config.sops.defaultSopsFile;
            });
          };
          # sops-nix refuses a key file in the store.
          system.activationScripts = {
            sops-test-age-key = stringAfter [ ] ''
              install -D -m 0400 ${sopsSecrets}/age-key.txt ${ageKeyFile}
            '';
            setupSecrets.deps = [ "sops-test-age-key" ];
          };

          qois.kanidm = {
            enable = true;
            package = kanidmPackage;
            domain = cfg.kanidmDomain;
            secretsFile = mkForce config.sops.defaultSopsFile;
          };

          networking.firewall.allowedTCPPorts = [
            80
            443
          ];

          # Pebble generates its issuing CA at startup.
          systemd.services = {
            pebble-ca = {
              description = "Download the CA of pebble";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              path = [ curl ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                until curl -sf https://${cfg.caDomain}:15000/roots/0 > ${cfg.caFile}.tmp; do
                  sleep 1
                done
                curl -sf https://${cfg.caDomain}:15000/intermediate-keys/0 >> ${cfg.caFile}.tmp
                mv ${cfg.caFile}.tmp ${cfg.caFile}
              '';
            };
          }
          // genAttrs cfg.pebbleCaClients (_unit: {
            after = [ "pebble-ca.service" ];
            wants = [ "pebble-ca.service" ];
            environment.SSL_CERT_FILE = cfg.caFile;
          });

          environment.systemPackages = [
            curl
            oidcLogin
            testPerson
          ];
        };
    };
  };
}
