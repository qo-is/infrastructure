{
  pkgs,
  ...
}:

{
  environment.systemPackages =
    with pkgs;
    [
      vim
      tmux
      killall
      bc
      rename
      wipe
      gnupg
      ripgrep
    ]
    ++ [
      nix-index
      nix-diff
    ]
    ++ [
      autojump
      powerline-go
    ]
    ++ [
      # File Utilities
      ack
      unzip
      iotop
      tree
      vim
      vimPlugins.pathogen
      vimPlugins.airline
      git
      git-lfs
    ]
    ++ [
      # Filesystem & Disk Utilities
      parted
    ]
    ++ [
      # Networking Utilities
      nmap
      bind
      curl
      wget
      rsync
      iftop
      mailutils
    ];
}
