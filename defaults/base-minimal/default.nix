{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./unfree.nix
    ./applications.nix
    ./overlays.nix
    ./security.nix
  ];

  boot.loader.timeout = 2;
  boot.tmp.useTmpfs = true;
  boot.loader.grub.splashImage = null;

  console.keyMap = "de_CH-latin1";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.kernel.sysctl = {
    "kernel.panic" = 20; # Reboot kernel on panic after this much seconds
  };

  boot.initrd.network.udhcpc.extraArgs = [
    "-A"
    "900" # Wait for a DHCP lease on boot for 15mins
  ];

  systemd.watchdog = {
    runtimeTime = "5m";
    rebootTime = "10m";
  };

  users.mutableUsers = false;
  users.users = {
    root.openssh.authorizedKeys.keys =
      with lib;
      concatLists (
        mapAttrsToList (
          name: user:
          if elem "wheel" user.extraGroups && name != "root" then user.openssh.authorizedKeys.keys else [ ]
        ) config.users.users
      );
  };

  # Disable dependency on xorg
  # TODO: Set environment.noXlibs on hosts that don't need any x libraries.
  security.pam.services.su.forwardXAuth = lib.mkForce false;

  # Package management
  nix = {
    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      substituters = [
        "https://${inputs.self.nixosConfigurations.lindberg-build.config.qois.nixpkgs-cache.hostname}?priority=39"
        "https://cache.nixos.org?priority=40"
        "https://attic.qo.is/qois-infrastructure"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "qois-infrastructure:lh35ymN7Aoxm5Hz0S6JusxE+cYzMU+x9OMKjDVIpfuE="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 90d";
    };
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  system.autoUpgrade = {
    enable = true;
    randomizedDelaySec = "30m";
    flags = [
      "--update-input"
      "nixpkgs-nixos-2211"
      "--commit-lock-file"
    ];
  };

  # Network services
  networking.firewall = {
    allowPing = true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;

    # temporary mitigation agains CVE-2024-6387 «regreSSHion» RCE
    # See https://github.com/NixOS/nixpkgs/pull/323753#issuecomment-2199762128
    settings.LoginGraceTime = 0;
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "sysadmin@qo.is";
  };

  # Default Settings
  environment.etc = {
    gitconfig.source = ./etc/gitconfig;
    vimrc.source = ./etc/vimrc;
  };

  programs.autojump.enable = true;
  programs.vim.defaultEditor = true;

  sops.defaultSopsFile =
    let
      defaultSopsPath = "${inputs.private}/nixos-configurations/${config.networking.hostName}/secrets.sops.yaml";
    in
    lib.mkIf (builtins.pathExists defaultSopsPath) defaultSopsPath;

  services.fstrim.enable = true;

  qois.outgoing-server-mail.enable = true;
  qois.backup-client.enable = true;

  systemd.extraConfig = "DefaultLimitNOFILE=4096";
}
