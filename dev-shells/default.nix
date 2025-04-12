{
  pkgs,
  git-hooks-nix,
  treefmtEval,
  system,
  self,
  ...
}:
let
  pre-commit-check = git-hooks-nix.lib.${system}.run {
    src = ../.;
    hooks.treefmt = {
      enable = true;
      package = treefmtEval.config.build.wrapper;
      always_run = true;
    };
  };
in
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
      pre-commit-check.enabledPackages
      ++ [ vscodium-with-extensions ]
      ++ (with self.packages.${system}; [
        sops
        sops-rekey
        auto-deploy
      ])
      ++ (with pkgs; [
        attic-client
        deploy-rs
        jq
        nix-fast-build
        nixVersions.latest
        nixd
        nixfmt-rfc-style
        nixos-anywhere
        pssh
        ssh-to-age
        yq
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

      ${pre-commit-check.shellHook}
    '';
  };
}
