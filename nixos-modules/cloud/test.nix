{
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    attrNames
    concatStringsSep
    getExe
    mkForce
    ;
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;
  adminPass = "snakeoilAdminPass";
in
{ config, ... }:
{
  args = {
    inherit serverDomain adminPass;
    apps = concatStringsSep "," (attrNames config.nodes.server.services.nextcloud.extraApps);
  };

  nodes.server =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (pkgs) writeText;
    in
    {
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;

      security.pki.certificateFiles = [ certs.ca.cert ];

      qois.cloud = {
        enable = true;
        domain = serverDomain;
        package = pkgs.nextcloud35;
      };

      sops.secrets = mkForce { };
      services.nextcloud.config.adminpassFile = mkForce "${writeText "nextcloud-admin-pass" adminPass}";
      qois.postgresql.package = pkgs.postgresql;

      services.nginx.virtualHosts.${serverDomain} = {
        enableACME = mkForce false;
        sslCertificate = certs.${serverDomain}.cert;
        sslCertificateKey = certs.${serverDomain}.key;
      };

      # Nextcloud's HTTP client only trusts its bundled CA list, not the system trust store.
      systemd.services.nextcloud-notify_push_setup = {
        after = [ "nginx.service" ];
        preStart = "${getExe config.services.nextcloud.occ} security:certificates:import ${certs.ca.cert}";
      };

      qois.telegraf.enable = mkForce true;
      services.telegraf.extraConfig.agent.interval = mkForce "50ms";
      # Drop the host-level inputs of the telegraf module and srvos; only the inputs the
      # modules under test contribute are relevant here.
      services.telegraf.extraConfig.inputs = mkForce config.qois.telegraf.serviceInputs;
    };
}
