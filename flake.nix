{
  description = "qo.is infrastructure: Host and Network Configuration";
  nixConfig = {
    extra-substituters = "https://attic.qo.is/qois-infrastructure";
    extra-trusted-public-keys = "qois-infrastructure:lh35ymN7Aoxm5Hz0S6JusxE+cYzMU+x9OMKjDVIpfuE=";
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    private.url = "git+file:./private";
    private.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      # Packages for development and build process
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs.lib) recursiveUpdate;

      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (_self: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };

      # Create input sets to reduce risk of cyclic dependencies.
      extendSelfOf = old: self: recursiveUpdate old { inherit self; };
      inputSubsetExternal = {
        inherit pkgs;
        inherit deployPkgs;
        inherit system;
        inherit (inputs)
          deploy-rs
          disko
          nix-topology
          nixpkgs
          sops-nix
          srvos
          private
          git-hooks-nix
          treefmt-nix
          ;

        ### Usage of self directly should be avoided, to reduce the risk of cyclic dependencies.
        flakeSelfSpecialUsage = self;
        self = { };
      };
      inputSubsetWithLibAndFormatter = extendSelfOf inputSubsetExternal {
        inherit (self) lib formatter;
      };
      inputSubsetWithPackages = extendSelfOf inputSubsetWithLibAndFormatter {
        inherit (self) packages;
      };
      inputSubsetForNixosModules = inputSubsetWithPackages;
      inputSubsetForNixosConfigurations = extendSelfOf inputSubsetWithPackages {
        inherit (self) nixosModules devShells;
      };
      inputSubsetForDeploy = extendSelfOf inputSubsetForNixosConfigurations {
        inherit (self) nixosConfigurations;
      };
      inputSubsetForChecks =
        (extendSelfOf inputSubsetForDeploy {
          inherit (self) deploy topology;
        })
        // {
          inherit inputSubsetForNixosConfigurations;
        }; # We have nixos tests that need to pass the relevant specialArgs.
    in
    {
      ## Dependency graph: checks -> (deploy, topology) -> nixosConfigurations -> (nixosModules, devShells) -> packages🔄 -> (lib, formatter)
      ## Exception: packages.docs embeds the rendered topology diagrams and therefore reaches
      ## back to topology via flakeSelfSpecialUsage. Nothing below nixosConfigurations uses
      ## packages.docs, so this back edge stays acyclic.
      checks = import ./checks/default.nix inputSubsetForChecks;
      deploy = import ./deploy/default.nix inputSubsetForDeploy;
      topology = import ./topology/default.nix inputSubsetForDeploy;
      nixosConfigurations = import ./nixos-configurations/default.nix inputSubsetForNixosConfigurations;
      nixosModules = import ./nixos-modules/default.nix inputSubsetForNixosModules;
      devShells = import ./dev-shells/default.nix inputSubsetWithPackages;
      packages = import ./packages/default.nix inputSubsetWithPackages;
      lib = import ./lib/default.nix inputSubsetExternal;
      formatter.${system} =
        let
          inherit (inputSubsetExternal) pkgs treefmt-nix;
        in
        (treefmt-nix.lib.evalModule pkgs ./treefmt.nix).config.build.wrapper;

    };
}
