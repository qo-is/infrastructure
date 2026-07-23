def test(machine, subtest):
    machine.start()
    machine.wait_for_unit("multi-user.target")

    with subtest("Secure Boot keys are auto-generated into the persistent pkiBundle"):
        machine.wait_for_unit("generate-sb-keys.service")
        machine.succeed("test -f /var/lib/sbctl/keys/db/db.pem")
        machine.succeed("test -f /var/lib/sbctl/keys/db/db.key")

    with subtest("boot artifacts are installed and signed on the primary ESP"):
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
        machine.wait_for_unit("systemd-pcrlock-firmware-code.service")
        machine.wait_for_unit("systemd-pcrlock-make-policy.service")
        machine.succeed("test -f /var/lib/systemd/pcrlock.json")
