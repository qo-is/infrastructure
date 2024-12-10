{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.qois.git-ci-runner;
  defaultInstanceName = "default";
in
with lib;
{
  options.qois.git-ci-runner = {
    enable = mkEnableOption "Enable qois git ci-runner service";

    domain = mkOption {
      type = types.str;
      default = "git.qo.is";
      description = "Domain, under which the service is served.";
    };

    nixInstances = mkOption {
      type = types.numbers.positive;
      default = 10;
      description = "How many nix runner instances to start";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {

      sops.secrets."forgejo/runner-registration-token".restartUnits = [
        "gitea-runner-${defaultInstanceName}.service"
      ] ++ (genList (n: "gitea-runner-nix${builtins.toString n}.service") cfg.nixInstances);

      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        autoPrune.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      services.gitea-actions-runner = {
        package = pkgs.forgejo-runner;
        instances.${defaultInstanceName} = {
          enable = true;
          name = "${config.networking.hostName}-${defaultInstanceName}";
          url = "https://${cfg.domain}";
          tokenFile = config.sops.secrets."forgejo/runner-registration-token".path;
          labels = [
            "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
            "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
            "docker:docker://code.forgejo.org/oci/alpine:3.20"
          ];
          settings = {
            log.level = "warn";
            runner = {
              capacity = 30;
            };
            cache.enable = true; # TODO: This should probably be a central cache server?
            container.network = "host";
          };
        };
      };
    }

    {
      # everything here has no dependencies on the store
      systemd.services.gitea-runner-nix-image = {
        wantedBy = [ "multi-user.target" ];
        after = [ "podman.service" ];
        requires = [ "podman.service" ];
        path = [
          config.virtualisation.podman.package
          pkgs.gnutar
          pkgs.shadow
          pkgs.getent
        ];
        # we also include etc here because the cleanup job also wants the nixuser to be present
        script = ''
          set -eux -o pipefail
          mkdir -p etc/nix

          # Create an unpriveleged user that we can use also without the run-as-user.sh script
          touch etc/passwd etc/group
          groupid=$(cut -d: -f3 < <(getent group nixuser))
          userid=$(cut -d: -f3 < <(getent passwd nixuser))
          groupadd --prefix $(pwd) --gid "$groupid" nixuser
          emptypassword='$6$1ero.LwbisiU.h3D$GGmnmECbPotJoPQ5eoSTD6tTjKnSWZcjHoVTkxFLZP17W9hRi/XkmCiAMOfWruUwy8gMjINrBMNODc7cYEo4K.'
          useradd --prefix $(pwd) -p "$emptypassword" -m -d /tmp -u "$userid" -g "$groupid" -G nixuser nixuser

          cp -a ${config.environment.etc."nix/nix.conf".source} etc/nix/nix.conf

          cat <<NIX_CONFIG >> etc/nix/nix.conf
          accept-flake-config = true
          NIX_CONFIG

          cat <<NSSWITCH > etc/nsswitch.conf
          passwd:    files mymachines systemd
          group:     files mymachines systemd
          shadow:    files

          hosts:     files mymachines dns myhostname
          networks:  files

          ethers:    files
          services:  files
          protocols: files
          rpc:       files
          NSSWITCH

          # list the content as it will be imported into the container
          tar -cv . | tar -tvf -
          tar -cv . | podman import - gitea-runner-nix
        '';
        serviceConfig = {
          RuntimeDirectory = "gitea-runner-nix-image";
          WorkingDirectory = "/run/gitea-runner-nix-image";
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      users.users.nixuser = {
        group = "nixuser";
        description = "Used for running nix ci jobs";
        home = "/var/empty";
        isSystemUser = true;
      };
      users.groups.nixuser = { };
    }
    {
      virtualisation = {
        podman.enable = true;
      };

      virtualisation.containers.storage.settings = {
        storage.driver = "btrfs";
        storage.graphroot = "/var/lib/containers/storage";
        storage.runroot = "/run/containers/storage";
      };

    }
    {
      systemd.services =
        genAttrs (genList (n: "gitea-runner-nix${builtins.toString n}") cfg.nixInstances)
          (name: {
            after = [
              "gitea-runner-nix-image.service"
            ];
            requires = [
              "gitea-runner-nix-image.service"
            ];

            # TODO: systemd confinment
            serviceConfig = {
              # Hardening (may overlap with DynamicUser=)
              # The following options are only for optimizing output of systemd-analyze
              AmbientCapabilities = "";
              CapabilityBoundingSet = "";
              # ProtectClock= adds DeviceAllow=char-rtc r
              DeviceAllow = "";
              NoNewPrivileges = true;
              PrivateDevices = true;
              PrivateMounts = true;
              PrivateTmp = true;
              PrivateUsers = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectSystem = "strict";
              RemoveIPC = true;
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              UMask = "0066";
              ProtectProc = "invisible";
              SystemCallFilter = [
                "~@clock"
                "~@cpu-emulation"
                "~@module"
                "~@mount"
                "~@obsolete"
                "~@raw-io"
                "~@reboot"
                "~@swap"
                # needed by go?
                #"~@resources"
                "~@privileged"
                "~capset"
                "~setdomainname"
                "~sethostname"
              ];
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
                "AF_NETLINK"
              ];

              # Needs network access
              PrivateNetwork = false;
              # Cannot be true due to Node
              MemoryDenyWriteExecute = false;

              # The more restrictive "pid" option makes `nix` commands in CI emit
              # "GC Warning: Couldn't read /proc/stat"
              # You may want to set this to "pid" if not using `nix` commands
              ProcSubset = "all";
              # Coverage programs for compiled code such as `cargo-tarpaulin` disable
              # ASLR (address space layout randomization) which requires the
              # `personality` syscall
              # You may want to set this to `true` if not using coverage tooling on
              # compiled code
              LockPersonality = false;

              # Note that this has some interactions with the User setting; so you may
              # want to consult the systemd docs if using both.
              DynamicUser = true;
            };
          });

      services.gitea-actions-runner.instances =
        let
          storeDeps = pkgs.runCommand "store-deps" { } ''
            mkdir -p $out/bin
            for dir in ${
              toString [
                pkgs.bash
                pkgs.coreutils
                pkgs.findutils
                pkgs.gawk
                pkgs.git
                pkgs.gnugrep
                pkgs.jq
                pkgs.nix
                pkgs.nodejs
                pkgs.openssh
              ]
            }; do
              for bin in "$dir"/bin/*; do
                ln -s "$bin" "$out/bin/$(basename "$bin")"
              done
            done

            # Add SSL CA certs
            mkdir -p $out/etc/ssl/certs
            cp -a "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" $out/etc/ssl/certs/ca-bundle.crt
          '';
        in
        genAttrs (genList (n: "nix${builtins.toString n}") cfg.nixInstances) (name: {
          enable = true;
          name = "${config.networking.hostName}-${name}";
          url = "https://${cfg.domain}";
          tokenFile = config.sops.secrets."forgejo/runner-registration-token".path;
          labels = [ "nix:docker://gitea-runner-nix" ];
          settings = {
            container.options = "-e NIX_BUILD_SHELL=/bin/bash -e PAGER=cat -e PATH=/bin -e SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt --device /dev/kvm -v /nix:/nix -v ${storeDeps}/bin:/bin -v ${storeDeps}/etc/ssl:/etc/ssl --user nixuser --device=/dev/kvm";
            container.network = "host";
            container.valid_volumes = [
              "/nix"
              "${storeDeps}/bin"
              "${storeDeps}/etc/ssl"
            ];
          };
        });
    }
  ]);

}
