{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib)
    concatLists
    elem
    mapAttrsToList
    ;
in
{
  imports = [
    inputs.srvos.nixosModules.server

    ./applications.nix
    ./overlays.nix
    ./physical.nix
    ./security.nix
    ./virtual-machine.nix
  ];

  boot.loader.timeout = 2;
  boot.tmp.useTmpfs = true;
  boot.loader.grub.splashImage = null;
  boot.loader.systemd-boot.editor = false;

  console.keyMap = "de_CH-latin1";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.kernel.sysctl = {
    "kernel.panic" = 20; # Reboot kernel on panic after this much seconds
  };

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

  # Package management
  nix = {
    settings =
      let
        substituters = [
          #"https://${config.qois.nixpkgs-cache.hostname}?priority=30" # TODO: Re-enable this once we have a stable solution
          "https://attic.qo.is/qois-infrastructure?priority=32"
          "https://cache.nixos.org?priority=40"
        ];
      in
      {
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
  };

  # Network services
  networking.firewall.allowPing = true;

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

  services.fstrim.enable = true;

  qois.outgoing-server-mail.enable = true;
  qois.backup-client.enable = true;

  systemd.settings.Manager.DefaultLimitNOFILE = 4096;

  networking.useNetworkd = false;
}
