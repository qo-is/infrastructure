{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.qois.microvm;

  shareSubmodule = types.submodule {
    options = {
      tag = mkOption {
        type = types.str;
        description = "Virtiofs tag for the share.";
      };
      source = mkOption {
        type = types.str;
        description = "Host path to share.";
      };
      mountPoint = mkOption {
        type = types.str;
        description = "Guest mount point.";
      };
    };
  };

  serviceSubmodule = types.submodule (
    { name, ... }:
    {
      options = {
        enable = mkEnableOption "microvm service ${name}";

        guestModules = mkOption {
          type = types.listOf types.deferredModule;
          default = [ ];
          description = "NixOS modules to import inside the guest VM.";
        };

        vcpus = mkOption {
          type = types.int;
          default = 2;
          description = "Number of virtual CPUs.";
        };

        mem = mkOption {
          type = types.int;
          default = 2048;
          description = "Memory in MiB.";
        };

        index = mkOption {
          type = types.ints.positive;
          description = "VM index for IP allocation. Guest IP = subnet_base + index + 1.";
        };

        shares = mkOption {
          type = types.listOf shareSubmodule;
          default = [ ];
          description = "Extra virtiofs shares (data volumes).";
        };

        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Other microvm service names this VM depends on.";
        };

        openHostFirewallTCP = mkOption {
          type = types.listOf types.port;
          default = [ ];
          description = "TCP ports to allow on the host firewall for this VM's tap interface.";
        };

        openHostFirewallUDP = mkOption {
          type = types.listOf types.port;
          default = [ ];
          description = "UDP ports to allow on the host firewall for this VM's tap interface.";
        };
      };
    }
  );

  enabledServices = filterAttrs (_n: s: s.enable) cfg.services;

  # Build the list of dependent VM services
  dependencyServicesFor = svc: map (d: "microvm@${d}.service") svc.dependsOn;

in
{
  imports = [ ./networking.nix ];

  options.qois.microvm = {
    enable = mkEnableOption "microvm-based services";

    netName = mkOption {
      type = types.str;
      description = "Name of the microvm network in qois.meta.network.microvm.";
    };

    services = mkOption {
      type = types.attrsOf serviceSubmodule;
      default = { };
      description = "MicroVM service declarations.";
    };
  };

  config = mkIf cfg.enable {

    assertions =
      let
        indices = mapAttrsToList (_: svc: svc.index) enabledServices;
      in
      [
        {
          assertion = (unique (sort lessThan indices)) == (sort lessThan indices);
          message = "qois.microvm: service indices must be unique";
        }
      ];

    # VM dependency ordering
    systemd.services = mapAttrs' (
      vmName: vmCfg:
      nameValuePair "microvm@${vmName}" {
        after = dependencyServicesFor vmCfg;
        wants = dependencyServicesFor vmCfg;
      }
    ) enabledServices;

    # Declare microvm.vms for each enabled service
    microvm.vms = mapAttrs (
      _name: svc:
      let
        userShares = map (s: {
          inherit (s) tag source mountPoint;
          proto = "virtiofs";
        }) svc.shares;
      in
      {
        autostart = true;
        specialArgs = { };

        config = {
          imports = svc.guestModules;

          microvm = {
            hypervisor = "cloud-hypervisor";
            vcpu = svc.vcpus;
            mem = svc.mem;

            shares = [
              {
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                proto = "virtiofs";
              }
            ]
            ++ userShares;
          };

          system.stateVersion = config.system.stateVersion;
        };
      }
    ) enabledServices;
  };
}
