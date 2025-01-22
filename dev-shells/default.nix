{
  pkgs,
  system,
  self,
  ...
}:
{
  ${system}.default = pkgs.mkShellNoCC {
    name = "qois-infrastructure-shell";
    buildInputs =
      let
        vscodium-with-extensions = pkgs.vscode-with-extensions.override {
          vscodeExtensions = with pkgs.vscode-extensions; [ jnoortheen.nix-ide ];
          vscode = pkgs.vscodium;
        };
      in
      [ vscodium-with-extensions ]
      ++ (with self.packages.${system}; [
        cache
        deploy-qois
        sops
        sops-rekey
      ])
      ++ (with pkgs; [
        attic-client
        deploy-rs
        nixVersions.git
        nixd
        nixfmt-rfc-style
        nixos-anywhere
        ssh-to-age
        pssh
        yq
        jq
      ]);
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
    shellHook = ''
      # Bring xdg data dirs of dependencies and current program into the
      # environment. This will allow us to get shell completion if any
      # and there might be other benefits as well.
      xdg_inputs=( "''${buildInputs[@]}" )
      for p in "''${xdg_inputs[@]}"; do
        if [[ -d "$p/share" ]]; then
          XDG_DATA_DIRS="''${XDG_DATA_DIRS}''${XDG_DATA_DIRS+:}$p/share"
        fi
      done
      export XDG_DATA_DIRS

      # Make sure we support the pure case as well as non nixos cases
      # where dynamic bash completions were not sourced.
      #if ! type _completion_loader > /dev/null; then
      #  . ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
      #fi
    '';
  };
}
