{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.qois.microvm;
  helpers = import ./lib.nix { inherit lib; };

  # Network config derived from metadata
  netConfig = config.qois.meta.network.microvm.${cfg.netName};
  hostGateway = helpers.addToIPv4 netConfig.v4.id 1;
  guestIP = name: helpers.addToIPv4 netConfig.v4.id cfg.services.${name}.index;

  enabledServices = filterAttrs (_n: s: s.enable) cfg.services;
in
{
  config = mkIf cfg.enable {

    # Ensure host-side address configuration runs after the tap interface is created
    systemd.services = mapAttrs' (
      vmName: _vmCfg:
      nameValuePair "network-addresses-vm-${vmName}" {
        after = [ "microvm-tap-interfaces@${vmName}.service" ];
        wants = [ "microvm-tap-interfaces@${vmName}.service" ];
      }
    ) enabledServices;

    # Guest networking: tap interfaces and routed /32
    microvm.vms = mapAttrs (name: _svc: {
      config = {
        microvm.interfaces = [
          {
            type = "tap";
            id = "vm-${name}";
            mac = helpers.macAddress name;
          }
        ];

        networking.hostName = name;
        networking.useNetworkd = true;

        systemd.network.networks."10-eth" = {
          matchConfig.MACAddress = helpers.macAddress name;
          address = [
            "${guestIP name}/32"
          ];
          routes = [
            {
              Destination = "${hostGateway}/32";
              GatewayOnLink = true;
            }
            {
              Destination = "0.0.0.0/0";
              Gateway = hostGateway;
              GatewayOnLink = true;
            }
          ];
          networkConfig.DNS = [ hostGateway ];
        };
      };
    }) enabledServices;

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
            address = hostGateway;
            prefixLength = 32;
          }
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
