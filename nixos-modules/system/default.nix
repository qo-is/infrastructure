{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatLists
    elem
    mapAttrsToList
    mkForce
    ;
in
{
  imports = [
    ./applications.nix
    ./overlays.nix
    ./physical.nix
    ./security.nix
    ./virtual-machine.nix
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
      let
        wheelUserKeys = concatLists (
          mapAttrsToList (
            name: user:
            if elem "wheel" user.extraGroups && name != "root" then user.openssh.authorizedKeys.keys else [ ]
          ) config.users.users
        );
      in
      wheelUserKeys
      ++ [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBS65v7n5ozOUjYGuO/dgLC9C5MUGL5kTnQnvWAYP5B3 ci@git.qo.is"
      ];
  };

  # Disable dependency on xorg
  # TODO: Set environment.noXlibs on hosts that don't need any x libraries.
  security.pam.services.su.forwardXAuth = mkForce false;

  # Package management
  nix = {
    settings =
      let
        substituters = [
          "https://${config.qois.nixpkgs-cache.hostname}?priority=30"
          "https://attic.qo.is/qois-infrastructure?priority=32"
          "https://cache.nixos.org?priority=40"
        ];
      in
      {
        trusted-users = [
          "root"
          "@wheel"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "qois-infrastructure:lh35ymN7Aoxm5Hz0S6JusxE+cYzMU+x9OMKjDVIpfuE="
        ];
        trusted-substituters = substituters;
        inherit substituters;
      };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 90d";
    };
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Network services
  networking.firewall = {
    allowPing = true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
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
  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  services.fstrim.enable = true;

  qois.outgoing-server-mail.enable = true;
  qois.backup-client.enable = true;

  systemd.settings.Manager.DefaultLimitNOFILE = 4096;
}
