def test(machine, subtest):
    machine.start()
    machine.wait_for_unit("multi-user.target")

    with subtest("Secure Boot keys are auto-generated into the persistent pkiBundle"):
        machine.wait_for_unit("generate-sb-keys.service")
        machine.succeed("test -f /var/lib/sbctl/keys/db/db.pem")
        machine.succeed("test -f /var/lib/sbctl/keys/db/db.key")

    with subtest("boot artifacts are installed and signed on the primary ESP"):
        # lzbt parses the generation number from the nix profile symlink; a
        # fresh test VM has none, so lzbt would silently skip writing the
        # generation-named UKI without this (matches upstream's own
        # extra-efi-partitions.nix test setup).
        machine.succeed(
            "mkdir -p /nix/var/nix/profiles && "
            "ln -sf $(readlink -f /run/current-system) /nix/var/nix/profiles/system-1-link"
        )
        machine.succeed("/run/current-system/bin/switch-to-configuration boot")
        out = machine.succeed(
            "bootctl kernel-inspect /boot/EFI/Linux/nixos-generation-1-*.efi"
        )
        assert "Kernel Type: uki" in out

    with subtest("boot artifacts are mirrored onto the secondary ESP mount point"):
        out = machine.succeed(
            "bootctl kernel-inspect /boot2/EFI/Linux/nixos-generation-1-*.efi"
        )
        assert "Kernel Type: uki" in out

    with subtest(
        "keys are prepared for firmware auto-enrollment without forcing a reboot"
    ):
        machine.wait_for_unit("prepare-sb-auto-enroll.service")
        machine.succeed("test -f /boot/loader/keys/auto/PK.auth")
        machine.succeed("test -f /boot/loader/keys/auto/KEK.auth")
        machine.succeed("test -f /boot/loader/keys/auto/db.auth")

    with subtest("measured boot: pcrlock measurements and policy are generated"):
        # systemd-pcrlock-make-policy.service is a plain oneshot (no
        # RemainAfterExit) wanted by sysinit.target - it already ran and
        # went back to "inactive" well before this point in the test, so
        # wait_for_unit would fail here even on success. Check the artifact
        # it produces instead (systemd-pcrlock-firmware-code.service isn't
        # checked at all: it's unreliable in this VM/OVMF setup, which has no
        # /sys/kernel/security/tpm0/binary_bios_measurements event log).
        machine.succeed("test -f /var/lib/systemd/pcrlock.json")
