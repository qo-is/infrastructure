{ ... }:
{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    deadnix.enable = true;
    jsonfmt.enable = true;
    yamlfmt.enable = true;
    mdformat.enable = true;
    ruff-check.enable = true;
    ruff-format.enable = true;
    shfmt.enable = true;
  };
  settings = {
    global.excludes = [
      "*.jpg"
      "*.pdf"
      "*.toml"
    ]
    ++ [
      ".vscode/*"
      "nixos-modules/system/etc/*"
      "private"
      "private/*"

      ".envrc"
      "robots.txt"
    ];
    formatter.jsonfmt.excludes = [ ".vscode/*.json" ];
  };
}
