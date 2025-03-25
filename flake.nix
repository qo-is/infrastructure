{
  description = "qo.is infrastructure: Host and Network Configuration";
  nixConfig = {
    extra-substituters = "https://attic.qo.is/qois-infrastructure";
    extra-trusted-public-keys = "qois-infrastructure:lh35ymN7Aoxm5Hz0S6JusxE+cYzMU+x9OMKjDVIpfuE=";
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-nixos-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-nixos-stable";
    };
    private.url = "git+file:./private";
    private.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      # Packages for development and build process
      pkgs = import nixpkgs { inherit system; };
      deployPkgs = import nixpkgs {
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
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      importParams = {
        inherit (inputs)
          deploy-rs
          disko
          nixpkgs-nixos-stable
          sops-nix
          private
          ;
        inherit
          deployPkgs
          pkgs
          system
          treefmtEval
          ;
        flakeSelf = self;
      };
    in
    {
      checks = import ./checks/default.nix (
        importParams
        // {
          self = {
            inherit (self)
              lib
              packages
              nixosModules
              nixosConfigurations
              deploy
              ;
          };
        }
      );
      deploy = import ./deploy/default.nix (
        importParams
        // {
          self = {
            inherit (self)
              lib
              packages
              nixosModules
              nixosConfigurations
              ;
          };
        }
      );
      devShells = import ./dev-shells/default.nix (
        importParams
        // {
          self = {
            inherit (self) lib packages;
          };
        }
      );
      formatter.${system} = treefmtEval.config.build.wrapper;
      nixosConfigurations = import ./nixos-configurations/default.nix (
        importParams
        // {
          self = {
            inherit (self) lib packages nixosModules;
          };
        }
      );
      nixosModules = import ./nixos-modules/default.nix (
        importParams
        // {
          self = {
            inherit (self) lib packages;
          };
        }
      );
      packages = import ./packages/default.nix (
        importParams
        // {
          self = {
            inherit (self) lib packages;
          };
        }
      );
      lib = import ./lib/default.nix { inherit pkgs; };
    };
}
