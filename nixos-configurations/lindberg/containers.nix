{
  config,
  inputs,
  ...
}:
let
  containerNet = config.qois.meta.network.virtual.lindberg-containers-nat;
  containerIp = containerNet.hosts.lindberg-jellyfin.v4.ip;
in
{
  systemd.tmpfiles.settings."10-container-jellyfin" = {
    "/var/lib/jellyfin".d = {
      mode = "0755";
      user = "146";
      group = "169";
    };
  };

  containers.jellyfin = {
    autoStart = true;
    nixpkgs = inputs.nixpkgs;
    specialArgs = { inherit inputs; };

    config = {
      imports = [
        inputs.self.nixosModules.default
        ../lindberg-jellyfin
      ];
    };

    privateNetwork = true;
    hostAddress = containerNet.hosts.lindberg.v4.ip;
    localAddress = containerIp;

    privateUsers = "pick";
    extraFlags = [
      "--private-users-ownership=map"
      "--volatile=state"
      "--bind=/var/lib/jellyfin:/var/lib/jellyfin:idmap"
      "--bind=/mnt/data/media:/mnt/data/media:idmap"
      # Passes jellyfin secrets as systemd credentials into the container.
      # See nixos-modules/jellyfin/README.md for secret creation.
      "--load-credential=jellyfin-api-key:${config.sops.secrets."jellyfin/apiKey".path}"
      "--load-credential=jellyfin-admin-password:${config.sops.secrets."jellyfin/adminPassword".path}"
    ];

    tmpfs = [
      "/tmp"
      "/var/tmp"
    ];
  };

  systemd.services."container@jellyfin".serviceConfig = {
    MemoryHigh = "5G";
    MemoryMax = "20G";
    CPUQuota = "400%";
  };

  sops.secrets."jellyfin/apiKey".mode = "0400";
  sops.secrets."jellyfin/adminPassword".mode = "0400";

  networking.firewall.extraCommands = ''
    iptables -I FORWARD -s ${containerIp} -d 10.247.0.0/24 -j DROP
    iptables -I FORWARD -s ${containerIp} -d 10.248.0.0/24 -j DROP
    iptables -I FORWARD -s ${containerIp} -d 10.250.0.0/24 -j DROP
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D FORWARD -s ${containerIp} -d 10.247.0.0/24 -j DROP || true
    iptables -D FORWARD -s ${containerIp} -d 10.248.0.0/24 -j DROP || true
    iptables -D FORWARD -s ${containerIp} -d 10.250.0.0/24 -j DROP || true
  '';
}
