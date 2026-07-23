{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkForce
    mkDefault
    types
    head
    tail
    genAttrs
    removePrefix
    getExe'
    ;

  cfg = config.qois.lanzaboote;
  cryptenrollDeviceNames = builtins.attrNames cfg.autoCryptenroll.devices;
  primaryCryptenrollName =
    if cryptenrollDeviceNames == [ ] then null else head cryptenrollDeviceNames;
  secondaryCryptenrollNames =
    if cryptenrollDeviceNames == [ ] then [ ] else tail cryptenrollDeviceNames;
  pcrlockPolicy = config.boot.lanzaboote.measuredBoot.pcrlockPolicy;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.qois.lanzaboote = {
    enable = mkEnableOption "UEFI Secure Boot via Lanzaboote (systemd-boot + signed boot artifacts)";

    pkiBundle = mkOption {
      type = types.path;
      default = "/var/lib/sbctl";
      description = ''
        Persistent directory holding Secure Boot signing keys (db, KEK, PK).
        Must be on persistent storage that survives reboots.
      '';
    };

    extraEfiSysMountPoints = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional ESP mount points to install/sign boot artifacts to, besides
        `boot.loader.efi.efiSysMountPoint`. Used for mirrored multi-disk ESP setups.
      '';
    };

    autoCryptenroll.devices = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression "{ system = config.boot.initrd.luks.devices.crypted_system.device; }";
      description = ''
        LUKS devices (name -> device path, matching `boot.initrd.luks.devices.<name>.device`)
        to automatically bind to the measured-boot TPM2 pcrlock policy, so they unlock
        without a passphrase whenever the trusted boot chain is intact. Non-destructive:
        only adds/refreshes a TPM2 keyslot, never removes the existing password keyslot.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Lanzaboote installs via boot.loader.external; systemd-boot's own
    # installer must stay off to avoid two conflicting activation scripts.
    boot.loader.systemd-boot.enable = mkForce false;

    environment.systemPackages = [ pkgs.sbctl ];

    boot.lanzaboote = {
      enable = true;
      pkiBundle = cfg.pkiBundle;
      extraEfiSysMountPoints = cfg.extraEfiSysMountPoints;

      autoGenerateKeys.enable = true;
      autoEnrollKeys = {
        enable = true;
        autoReboot = false;
        includeMicrosoftKeys = true;
      };

      # configurationLimit must be in 1..8 whenever measuredBoot is enabled
      # (systemd-pcrlock's own hard limit) - the module's own default reads
      # boot.loader.systemd-boot.configurationLimit, which is null/unbounded
      # here since systemd-boot itself is disabled, so it must be set explicitly.
      configurationLimit = mkDefault 8;

      measuredBoot = {
        enable = true;
        pcrs = [
          0
          1
          2
          3
          4
          7
        ];

        # The built-in service only supports one device; it also re-runs
        # `lzbt install` to refresh the pcrlock policy before enrolling, which
        # secondary devices below rely on rather than repeating themselves.
        autoCryptenroll = mkIf (cryptenrollDeviceNames != [ ]) {
          enable = true;
          autoReboot = false;
          device = cfg.autoCryptenroll.devices.${primaryCryptenrollName};
        };
      };
    };

    # Additional LUKS devices beyond the first reuse the pcrlock policy that
    # auto-cryptenroll.service (above) already regenerated - each just needs
    # its own TPM2 keyslot enrolled against that same policy.
    systemd.services = genAttrs (map (name: "auto-cryptenroll-${name}") secondaryCryptenrollNames) (
      serviceName:
      let
        name = removePrefix "auto-cryptenroll-" serviceName;
        device = cfg.autoCryptenroll.devices.${name};
      in
      {
        after = [ "auto-cryptenroll.service" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig = {
          ConditionPathExists = "!/var/lib/auto-cryptenroll-${name}/1";
          ConditionSecurity = "uefi-secureboot";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "auto-cryptenroll-${name}";
        };
        script = ''
          ${getExe' pkgs.systemd "systemd-cryptenroll"} \
            --wipe-slot=tpm2 --tpm2-device=auto --unlock-tpm2-device=auto \
            --tpm2-pcrlock=${pcrlockPolicy} ${device}
          touch /var/lib/auto-cryptenroll-${name}/1
        '';
      }
    );
  };
}
