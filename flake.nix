{
  description = "qo.is infrastructure: Host and Network Configuration";
  nixConfig = {
    extra-substituters = "https://attic.qo.is/qois-infrastructure";
    extra-trusted-public-keys = "qois-infrastructure:lh35ymN7Aoxm5Hz0S6JusxE+cYzMU+x9OMKjDVIpfuE=";
  };
  inputs = {
    deploy-rs.url = "github:serokell/deploy-rs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-nixos-stable";
    };
    nixpkgs-nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-nixos-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs-nixos-unstable";
      };
    };
    private.url = "git+file:./private";
    private.inputs.nixpkgs-nixos-unstable.follows = "nixpkgs-nixos-unstable";
  };

  outputs =
    { nixpkgs-nixos-unstable, deploy-rs, ... }@inputs:
    let
      system = "x86_64-linux";
      # Packages for development and build process
      pkgs = import nixpkgs-nixos-unstable { inherit system; };
      deployPkgs = import nixpkgs-nixos-unstable {
        inherit system;
        overlays = [
          deploy-rs.overlay
          (self: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };
      importParams = inputs // {
        inherit pkgs;
        inherit deployPkgs;
        inherit system;
      };
    in
    {
      checks = import ./checks/default.nix importParams;
      deploy = import ./deploy/default.nix importParams;
      devShells = import ./dev-shells/default.nix importParams;
      formatter.${system} = pkgs.writeShellScriptBin "formatter" ''
        ${pkgs.findutils}/bin/find $1 -type f -name '*.nix' -exec ${pkgs.nixfmt-rfc-style}/bin/nixfmt ''${@:2} {} +
      '';
      nixosConfigurations = import ./nixos-configurations/default.nix importParams;
      nixosModules = import ./nixos-modules/default.nix importParams;
      packages = import ./packages/default.nix importParams;
      lib = import ./lib/default.nix importParams;
    };
}
