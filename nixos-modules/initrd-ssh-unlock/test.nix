{ lib, ... }:
{
  # Default `virtualisation.vlans = [ 1 ]` gives both nodes an "eth1"
  # interface addressed 192.168.1.<nodeNumber>; nodes are numbered
  # alphabetically, so client=1, server=2.
  nodes.server = {
    testing.initrdBackdoor = true;

    qois.initrd-ssh-unlock = {
      enable = true;
      interface = "eth1";
      ip = "192.168.1.2/24";
      sshPort = 2222;
      sshHostKey = ./test-keys/ssh_host_ed25519_key;
    };

    users.users.test-admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # The module only collects `.keys` (matching the old luks-ssh module),
      # not `.keyFiles`.
      openssh.authorizedKeys.keys = [ (lib.fileContents ./test-keys/id_ed25519.pub) ];
    };
  };

  nodes.client = {
    environment.etc = {
      knownHosts.text = "192.168.1.2 ${lib.fileContents ./test-keys/ssh_host_ed25519_key.pub}";
      sshKey = {
        source = ./test-keys/id_ed25519;
        mode = "0600";
      };
    };
  };
}
