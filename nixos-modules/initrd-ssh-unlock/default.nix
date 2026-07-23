{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkForce
    types
    pipe
    attrValues
    filter
    elem
    concatMap
    ;

  cfg = config.qois.initrd-ssh-unlock;
in
{
  options.qois.initrd-ssh-unlock = {
    # Under systemd initrd, `cryptsetup-askpass` doesn't exist. Connect with
    # `ssh -o RequestTTY=force -p <sshPort> root@<host>` and the forced
    # `command="systemctl default"` on each authorized key runs the
    # equivalent: it prompts for any pending LUKS passphrases on the ssh TTY.
    enable = mkEnableOption "SSH-based remote LUKS unlock via systemd initrd";

    interface = mkOption {
      type = types.str;
      example = "enp0s31f6";
      description = ''
        Interface name used during initrd. Under systemd initrd, udev's
        predictable interface naming is already active, so this should
        match the interface name used in the normal system configuration.
      '';
    };

    ip = mkOption {
      type = types.str;
      default = "dhcp";
      example = "192.168.0.10/24";
      description = ''
        Static IP address in CIDR notation, or "dhcp" (default).
      '';
    };

    gateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "192.168.0.1";
      description = ''
        IP of the gateway. Required when `ip` is set to a static address.
      '';
    };

    sshHostKey = mkOption {
      type = types.either types.str types.path;
      description = ''
        Hostkey for ssh connection.
        The key is stored in an unencrypted form,
        so it is strongly advised against using the normal host key.

        You can generate a host key with:

        ssh-keygen -t ed25519 -N "" -f /secrets/initrd_ssh_key_ed25519
      '';
    };

    sshPort = mkOption {
      type = types.port;
      default = 2222;
      description = ''
        SSH Port of the initrd ssh server.
        Should be different from default SSH port to prevent known hosts collisions.
      '';
    };
  };

  config = mkIf cfg.enable {
    # qois.system.physical defaults these for the legacy busybox initrd; both
    # are incompatible with (and asserted against by) systemd stage 1.
    boot.initrd.systemd.enable = mkForce true;
    boot.initrd.network.udhcpc.extraArgs = mkForce [ ];

    boot.initrd.systemd.network = {
      enable = true;
      networks."10-${cfg.interface}" = {
        matchConfig.Name = cfg.interface;
        networkConfig.DHCP = mkIf (cfg.ip == "dhcp") "ipv4";
        address = mkIf (cfg.ip != "dhcp") [ cfg.ip ];
        routes = mkIf (cfg.ip != "dhcp" && cfg.gateway != null) [ { Gateway = cfg.gateway; } ];
        linkConfig.RequiredForOnline = "routable";
      };
    };

    boot.initrd.network.ssh = {
      enable = true;
      port = cfg.sshPort;
      hostKeys = [ cfg.sshHostKey ];
      authorizedKeys = pipe config.users.users [
        attrValues
        (filter (user: elem "wheel" user.extraGroups))
        (concatMap (
          user: map (key: ''command="systemctl default" ${key}'') user.openssh.authorizedKeys.keys
        ))
      ];
    };
  };
}
