{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.qois.microvm;

  # Deterministic MAC from VM name: 02:xx:xx:xx:xx:xx (locally-administered)
  macAddress =
    name:
    let
      hash = builtins.hashString "sha256" "microvm-${name}";
      hex = c: builtins.substring c 2 hash;
    in
    "02:${hex 0}:${hex 2}:${hex 4}:${hex 6}:${hex 8}";

  secretSubmodule = types.submodule {
    options = {
      generator = mkOption {
        type = types.str;
        default = "${pkgs.pwgen}/bin/pwgen -s 32 1";
        description = "Shell command that outputs the secret value to stdout.";
      };
      fileName = mkOption {
        type = types.str;
        default = "password";
        description = "Name of the file inside the secret directory.";
      };
    };
  };

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

        hostAddress = mkOption {
          type = types.str;
          description = "Host-side IP for the point-to-point link.";
        };

        guestAddress = mkOption {
          type = types.str;
          description = "Guest-side IP for the point-to-point link.";
        };

        shares = mkOption {
          type = types.listOf shareSubmodule;
          default = [ ];
          description = "Extra virtiofs shares (data volumes).";
        };

        secrets = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Names from qois.microvm.secrets this VM needs access to.";
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

  # All tap interface names for NAT
  tapInterfaces = mapAttrsToList (name: _: "vm-${name}") enabledServices;

  # Build the list of secret generation services needed before a given VM
  secretServicesFor = svc: map (s: "microvm-secret-${s}.service") svc.secrets;

  # Build the list of dependent VM services
  dependencyServicesFor = svc: map (d: "microvm@${d}.service") svc.dependsOn;

in
{
  options.qois.microvm = {
    enable = mkEnableOption "microvm-based services";

    secrets = mkOption {
      type = types.attrsOf secretSubmodule;
      default = { };
      description = "Secrets to generate on the host and share with VMs via virtiofs.";
    };

    services = mkOption {
      type = types.attrsOf serviceSubmodule;
      default = { };
      description = "MicroVM service declarations.";
    };
  };

  config = mkIf cfg.enable {

    # Secret generation: one systemd oneshot per secret
    systemd.services = mkMerge [
      # Secret generators
      (mapAttrs' (
        secretName: secretCfg:
        nameValuePair "microvm-secret-${secretName}" {
          description = "Generate microvm secret: ${secretName}";
          wantedBy = [ "multi-user.target" ];
          before =
            # Before all VMs that use this secret
            concatLists (
              mapAttrsToList (
                vmName: vmCfg: optional (elem secretName vmCfg.secrets) "microvm@${vmName}.service"
              ) enabledServices
            );
          unitConfig.ConditionPathExists = "!/dev/shm/microvm-secrets/${secretName}/${secretCfg.fileName}";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            mkdir -p /dev/shm/microvm-secrets/${secretName}
            ${secretCfg.generator} > /dev/shm/microvm-secrets/${secretName}/${secretCfg.fileName}
            chmod 400 /dev/shm/microvm-secrets/${secretName}/${secretCfg.fileName}
            chmod 500 /dev/shm/microvm-secrets/${secretName}
          '';
        }
      ) cfg.secrets)

      # VM dependency ordering and secret dependencies
      (mapAttrs' (
        vmName: vmCfg:
        nameValuePair "microvm@${vmName}" {
          after = (secretServicesFor vmCfg) ++ (dependencyServicesFor vmCfg);
          wants = (secretServicesFor vmCfg) ++ (dependencyServicesFor vmCfg);
        }
      ) enabledServices)
    ];

    # Declare microvm.vms for each enabled service
    microvm.vms = mapAttrs (
      name: svc:
      let
        secretShares = map (s: {
          tag = "secret-${s}";
          source = "/dev/shm/microvm-secrets/${s}";
          mountPoint = "/run/microvm-secrets/${s}";
          proto = "virtiofs";
        }) svc.secrets;

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

            interfaces = [
              {
                type = "tap";
                id = "vm-${name}";
                mac = macAddress name;
              }
            ];

            shares = [
              {
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                proto = "virtiofs";
              }
            ]
            ++ secretShares
            ++ userShares;
          };

          # Guest networking: point-to-point /32
          networking.hostName = name;
          networking.useDHCP = false;
          networking.interfaces.eth0 = {
            useDHCP = false;
            ipv4.addresses = [
              {
                address = svc.guestAddress;
                prefixLength = 32;
              }
            ];
            ipv4.routes = [
              {
                address = svc.hostAddress;
                prefixLength = 32;
              }
            ];
          };
          networking.defaultGateway = {
            address = svc.hostAddress;
            interface = "eth0";
          };
          networking.nameservers = [ svc.hostAddress ];

          # Forward DNS to host
          system.stateVersion = config.system.stateVersion;
        };
      }
    ) enabledServices;

    # Host-side networking: tap interfaces with /32 addresses and routes
    networking.interfaces = mapAttrs' (
      name: svc:
      nameValuePair "vm-${name}" {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = svc.hostAddress;
            prefixLength = 32;
          }
        ];
        ipv4.routes = [
          {
            address = svc.guestAddress;
            prefixLength = 32;
          }
        ];
      }
    ) enabledServices;

    # NAT for microvm tap interfaces
    networking.nat.internalInterfaces = tapInterfaces;

    # Enable IP forwarding for inter-VM communication
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # Per-tap firewall rules
    networking.firewall.interfaces = mapAttrs' (
      name: svc:
      nameValuePair "vm-${name}" {
        allowedTCPPorts = svc.openHostFirewallTCP;
        allowedUDPPorts = svc.openHostFirewallUDP;
      }
    ) enabledServices;

    # Inter-VM forwarding: allow forwarding between all microvm tap interfaces
    networking.firewall.extraCommands =
      let
        pairs = concatLists (
          mapAttrsToList (
            n1: _:
            concatLists (
              mapAttrsToList (
                n2: _: optional (n1 != n2) "iptables -A FORWARD -i vm-${n1} -o vm-${n2} -j ACCEPT"
              ) enabledServices
            )
          ) enabledServices
        );
      in
      concatStringsSep "\n" pairs;
  };
}
