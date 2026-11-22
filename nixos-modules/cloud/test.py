import json


def assert_oneshot_succeeded(server, unit):
    server.wait_until_succeeds(
        f"test $(systemctl show -P ActiveState {unit}) = inactive"
        f" && test $(systemctl show -P ExecMainExitTimestampMonotonic {unit}) != 0"
    )
    result = server.succeed(f"systemctl show -P Result {unit}").strip()
    assert result == "success", f"{unit} result is {result}"


def test(server, serverDomain, adminPass, apps, subtest):
    server.wait_for_unit("phpfpm-nextcloud.service")
    base_url = f"https://{serverDomain}"

    with subtest("setup succeeded"):
        assert_oneshot_succeeded(server, "nextcloud-setup.service")

    with subtest("instance is installed and not in maintenance"):
        status = json.loads(server.succeed("nextcloud-occ status --output=json"))
        assert status["installed"], status
        assert not status["maintenance"], status

    with subtest("all configured apps are enabled"):
        enabled = json.loads(server.succeed("nextcloud-occ app:list --output=json"))[
            "enabled"
        ]
        missing = [app for app in apps.split(",") if app not in enabled]
        assert not missing, f"apps not enabled: {missing}"

    with subtest("nextcloud is served through nginx"):
        server.wait_for_unit("nginx.service")
        status_php = server.succeed(f"curl -sSf {base_url}/status.php")
        assert json.loads(status_php)["installed"], status_php

    with subtest("webdav round trip"):
        dav_url = f"{base_url}/remote.php/dav/files/root/test.txt"
        server.succeed("echo snakeoilContent > /tmp/upload.txt")
        server.succeed(f"curl -sSf -u root:{adminPass} -T /tmp/upload.txt {dav_url}")
        server.succeed(
            f"curl -sSf -u root:{adminPass} {dav_url} | diff - /tmp/upload.txt"
        )

    with subtest("redis is used"):
        dbsize = server.succeed(
            "redis-cli -s /run/redis-nextcloud/redis.sock dbsize"
        ).strip()
        assert int(dbsize) > 0, f"redis dbsize is {dbsize}"

    with subtest("notify_push setup succeeds"):
        assert_oneshot_succeeded(server, "nextcloud-notify_push_setup.service")

    with subtest("telegraf x509 metrics"):
        server.wait_for_unit("telegraf.service")
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c x509_cert"
        )
