def test(server, subtest):
    server.wait_for_unit("postgresql.service")
    server.wait_for_unit("telegraf.service")

    with subtest("postgresql-metrics"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -q postgresql_",
        )

    with subtest("major-version-upgrade"):
        server.succeed(
            "sudo -u postgres psql "
            "-c 'create table upgrade_probe (x int)' "
            "-c 'insert into upgrade_probe values (42)'"
        )

        server.succeed(
            "/run/current-system/specialisation/upgraded/bin/switch-to-configuration switch"
        )
        server.wait_for_unit("postgresql.service")

        version = server.succeed("sudo -u postgres psql -tAc 'show server_version'")
        assert version.strip().startswith("18"), (
            f"expected server_version 18.x after upgrade, got {version!r}"
        )

        probe = server.succeed(
            "sudo -u postgres psql -tAc 'select x from upgrade_probe'"
        )
        assert probe.strip() == "42", f"data lost across upgrade, got {probe!r}"

        server.succeed("test -e /var/lib/postgresql/14/PG_VERSION")

    with subtest("upgrade-is-idempotent"):
        server.succeed("systemctl restart postgresql-upgrade.service")
        condition_result = server.succeed(
            "systemctl show -p ConditionResult --value postgresql-upgrade.service"
        ).strip()
        assert condition_result == "no", (
            f"expected postgresql-upgrade.service to skip via its ConditionPathExists "
            f"on a second run, got ConditionResult={condition_result!r}"
        )
