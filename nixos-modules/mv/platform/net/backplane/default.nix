{config, lib, ...} :
let inherit (config.qois) services;
inherit (lib) mapAttrs;
in {
  qois.mesh = {
    hypervisors = {
      lindberg = {
        services-net-root.v4 = "10.2.3.";
      };
      cyprianspitz = {
        services-net-root.v4 = "10.1.3.";
      };
    };
  }
}