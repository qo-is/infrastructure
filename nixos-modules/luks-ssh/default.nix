{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.qois.luks-ssh;
in
{
  options.qois.luks-ssh = {
    enable = mkEnableOption "luks-ssh service";

    interface = mkOption {
      type = types.str;
      example = "enp0";
      description = ''
        Interface name.
      '';
    };

    ip = mkOption {
      type = types.str;
      example = "192.168.0.1";
      default = "dhcp";
      description = ''
        Host IP Address or "dhcp" (default).
      '';
    };

    gateway = mkOption {
      type = types.str;
      default = null;
      example = "192.168.0.1";
      description = ''
        IP of gateway. May be null if ip is aquired by dhcp.
      '';
    };

    netmask = mkOption {
      type = types.str;
      default = null;
      example = "192.168.0.1";
      description = ''
        Netmask of internal network. May be null if ip is aquired by dhcp.
      '';
    };

    sshHostKey = mkOption {
      type = types.str;
      default = "/secrets/initrd_ssh_key_ed25519";
      description = ''
        Hostkey for ssh connection.
        The key is stored in an unencrypted form,
        so it is strongly advised against using the normal host key.

        You can generate a host key with:

        ssh-keygen -t ed25519 -N "" -f /secrets/initrd_ssh_key_ed25519
      '';
    };

    sshPort = mkOption {
      type = types.addCheck types.int (n: n > 0 && n < 65536);
      default = 2222;
      description = ''
        SSH Port of the initrd ssh server.
        Should be different from default SSH port to prevent known hosts collissions.
      '';
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        port = cfg.sshPort;
        authorizedKeys =
          with lib;
          concatLists (
            mapAttrsToList (
              name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
            ) config.users.users
          );
        hostKeys = [ cfg.sshHostKey ];
      };
      postCommands = ''
        echo 'cryptsetup-askpass' >> /root/.profile
      '';
    };

    boot.initrd.network.udhcpc.enable = cfg.ip == "dhcp";
    boot.kernelParams =
      if cfg.ip == "dhcp" then
        [ ]
      else
        [
          "ip=${cfg.ip}::${cfg.gateway}:${cfg.netmask}:${config.networking.hostName}:${cfg.interface}:none"
        ]; # See boot.initrd.network.enable

    boot.initrd.postMountCommands = ''
      ip link set ${cfg.interface} down
    '';
  };
}
