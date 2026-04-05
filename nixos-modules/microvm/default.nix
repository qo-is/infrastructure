{
  config,
  lib,
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

  # IPv4 arithmetic helpers
  parseIPv4 = addr: map builtins.fromJSON (splitString "." addr);
  formatIPv4 = octets: concatStringsSep "." (map toString octets);
  addToIPv4 =
    addr: offset:
    let
      octets = parseIPv4 addr;
      total = foldl' (acc: o: acc * 256 + o) 0 octets + offset;
    in
    formatIPv4 [
      (mod (total / 16777216) 256)
      (mod (total / 65536) 256)
      (mod (total / 256) 256)
      (mod total 256)
    ];

  # Network config derived from metadata
  netConfig = config.qois.meta.network.microvm.${cfg.netName};
  hostGateway = addToIPv4 netConfig.v4.id 1;
  guestIP = name: addToIPv4 netConfig.v4.id (cfg.services.${name}.index + 1);

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

    systemd.services = mkMerge [
      # VM dependency ordering
      (mapAttrs' (
        vmName: vmCfg:
        nameValuePair "microvm@${vmName}" {
          after = dependencyServicesFor vmCfg;
          wants = dependencyServicesFor vmCfg;
        }
      ) enabledServices)

      # Ensure host-side address configuration runs after the tap interface is created
      (mapAttrs' (
        vmName: _vmCfg:
        nameValuePair "network-addresses-vm-${vmName}" {
          after = [ "microvm-tap-interfaces@${vmName}.service" ];
          wants = [ "microvm-tap-interfaces@${vmName}.service" ];
        }
      ) enabledServices)
    ];

    # Declare microvm.vms for each enabled service
    microvm.vms = mapAttrs (
      name: svc:
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
            ++ userShares;
          };

          # Guest networking: upstream-style routed /32
          networking.hostName = name;
          networking.useDHCP = false;
          networking.interfaces.eth0 = {
            useDHCP = false;
            ipv4.addresses = [
              {
                address = guestIP name;
                prefixLength = 32;
              }
            ];
            ipv4.routes = [
              {
                address = hostGateway;
                prefixLength = 32;
              }
            ];
          };
          networking.defaultGateway = {
            address = hostGateway;
            interface = "eth0";
          };
          networking.nameservers = [ hostGateway ];

          system.stateVersion = config.system.stateVersion;
        };
      }
    ) enabledServices;

    # Host-side networking: all taps share the gateway address, each has a /32 route to its guest
    networking.interfaces = mapAttrs' (
      name: _svc:
      nameValuePair "vm-${name}" {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = hostGateway;
            prefixLength = 32;
          }
        ];
        ipv4.routes = [
          {
            address = guestIP name;
            prefixLength = 32;
          }
        ];
      }
    ) enabledServices;

    # NAT for microvm subnet
    networking.nat.internalIPs = with netConfig.v4; [ "${id}/${toString prefixLength}" ];

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
