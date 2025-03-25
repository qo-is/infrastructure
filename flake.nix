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
    {
      self,
      nixpkgs-nixos-unstable,
      deploy-rs,
      ...
    }@inputs:
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
      importParams = {
        inherit (inputs)
          deploy-rs
          disko
          nixpkgs-nixos-stable
          sops-nix
          private
          ;
        inherit pkgs deployPkgs system;
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
      formatter.${system} = pkgs.nixfmt-tree;
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
