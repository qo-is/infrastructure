{
  config,
  lib,
  qoisMeta,
  ...
}:
let
  inherit (config.lib.topology)
    mkConnection
    mkDevice
    mkInternet
    mkRouter
    ;
  inherit (lib) mkForce;
  inherit (qoisMeta.network) physical;

  # Guests run on plain libvirtd, which nix-topology cannot detect on its own.
  mkVirtualMachine = parent: {
    inherit parent;
    guestType = "libvirt";
  };
in
{
  nodes = {
    internet = mkInternet {
      connections = [
        (mkConnection "media-converter-chur" "fiber")
        (mkConnection "riedbach-router" "wan")
      ];
    };

    media-converter-chur = mkDevice "Media Converter Chur" {
      info = "Passive media converter on Init7 fiber (1G/1G)";
      interfaceGroups = [
        [
          "fiber"
          "eth"
        ]
      ];
      connections.eth = mkConnection "calanda" "enp4s0";
    };

    riedbach-router = mkRouter "Riedbach Router" {
      info = "iway fiber (1G/1G), not managed by this repository";
      interfaceGroups = [
        [ "wan" ]
        [ "lan" ]
      ];
      connections.lan = mkConnection "lindberg" "enp5s0";
    };

    calanda.interfaces = {
      # Configured via DHCP, but Init7 always hands out the same address, which is
      # the one the rest of the world resolves calanda to.
      enp4s0 = {
        addresses = mkForce [ physical.plessur-ext.hosts.calanda.v4.ip ];
        network = "plessur-ext";
      };
      enp3s0.network = "plessur-dmz";
      lan.network = "plessur-lan";
    };

    cyprianspitz.interfaces = {
      enp0s31f6.physicalConnections = [ (mkConnection "calanda" "lan") ];
      vms-nat.network = "cyprianspitz-vms-nat";
    };

    lindberg.interfaces = {
      enp5s0.network = "riedbach-ext";
      vms-nat.network = "lindberg-vms-nat";
    };

    lindberg-nextcloud = mkVirtualMachine "lindberg" // {
      interfaces.enp2s0.physicalConnections = [ (mkConnection "lindberg" "vms-nat") ];
    };
    lindberg-build = mkVirtualMachine "lindberg" // {
      interfaces.enp11s0.physicalConnections = [ (mkConnection "lindberg" "vms-nat") ];
    };
    lindberg-webapps = mkVirtualMachine "lindberg" // {
      interfaces.enp1s0.physicalConnections = [ (mkConnection "lindberg" "vms-nat") ];
    };
  };
}
