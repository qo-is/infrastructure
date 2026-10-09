import json


def test(acme, server, caFile, prometheusDomain, kanidmDomain, subtest, **_):
    origin = f"https://{prometheusDomain}"
    curl = f"curl -s --cacert {caFile}"

    acme.wait_for_unit("pebble.service")
    server.wait_for_unit("pebble-ca.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("prometheus.service")
    server.wait_for_unit("alertmanager.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_unit("oauth2-proxy.service")
    server.wait_for_open_port(4180)

    with subtest("unauthenticated-redirect"):
        redirect_url = (
            f"{curl} -o /dev/null -w '%{{redirect_url}}' {origin}/alertmanager/"
        )
        server.wait_until_succeeds(f"{redirect_url} | grep -c oauth2/start")
        redirect = server.succeed(redirect_url)
        assert redirect.startswith(f"{origin}/oauth2/start"), (
            f"expected a redirect to oauth2-proxy but got '{redirect}'"
        )

    with subtest("sysadmin-login"):
        server.succeed("kanidm-test-person alice snakeoilAlicePassword sysadmin")
        landed = server.succeed(
            f"kanidm-oidc-login {origin}/alertmanager/ "
            "alice snakeoilAlicePassword /tmp/alice.cookies"
        ).strip()
        assert landed == f"{origin}/alertmanager/", (
            f"expected to land on the alertmanager UI but got '{landed}'"
        )

    with subtest("proxied-apis"):
        authenticated = f"{curl} -f --cookie /tmp/alice.cookies"
        status = json.loads(
            server.succeed(f"{authenticated} {origin}/alertmanager/api/v2/status")
        )
        assert "uptime" in status, f"expected the alertmanager status but got {status}"
        flags = json.loads(
            server.succeed(f"{authenticated} {origin}/api/v1/status/flags")
        )
        assert flags["data"]["web.external-url"] == f"{origin}/", (
            f"expected prometheus to know its public URL but got {flags}"
        )

    with subtest("non-sysadmin-denied"):
        server.succeed("kanidm-test-person bob snakeoilBobPassword prometheus.access")
        server.fail(
            f"kanidm-oidc-login {origin}/alertmanager/ "
            "bob snakeoilBobPassword /tmp/bob.cookies"
        )
