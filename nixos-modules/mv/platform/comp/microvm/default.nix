{...}: let cfg = config.qois.microvm; in {
  options.qois.microvm.enable = mkEnableOption "Whether this configuration is a microvm";

  config = mkIf cfg.enable = true {
    microvm = {
      hypervisor = "cloud-hypervisor";
      vcpu = 4;
      mem = "2048";
      interfaces = []; # TODO
      volumes = []; #TODO
      socket = #TODO;

    };
  };

}
