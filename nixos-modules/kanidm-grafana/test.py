import json


def test(acme, server, caFile, grafanaDomain, kanidmDomain, subtest, **_):
    acme.wait_for_unit("pebble.service")
    server.wait_for_unit("pebble-ca.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("grafana.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(3000)

    with subtest("oauth2-client-provisioned"):
        server.wait_until_succeeds(
            f"curl -sf --cacert {caFile} https://{kanidmDomain}"
            "/oauth2/openid/grafana/.well-known/openid-configuration"
        )

    with subtest("grafana-oauth-redirect"):
        redirect_url = (
            f"curl -s --cacert {caFile} -o /dev/null -w '%{{redirect_url}}' "
            f"https://{grafanaDomain}/login/generic_oauth"
        )
        server.wait_until_succeeds(f"{redirect_url} | grep -c oauth2")
        redirect = server.succeed(redirect_url)
        assert redirect.startswith(f"https://{kanidmDomain}/ui/oauth2"), (
            f"expected a redirect to the kanidm authorisation endpoint but got '{redirect}'"
        )
        assert "client_id=grafana" in redirect, (
            f"expected client_id=grafana in '{redirect}'"
        )
        assert "code_challenge=" in redirect, (
            f"expected a PKCE code_challenge in '{redirect}'"
        )

    with subtest("login"):
        server.succeed("kanidm-test-person alice snakeoilAlicePassword sysadmin")
        landed = server.succeed(
            f"kanidm-oidc-login https://{grafanaDomain}/login/generic_oauth "
            "alice snakeoilAlicePassword /tmp/alice.cookies"
        ).strip()
        assert landed.startswith(f"https://{grafanaDomain}/"), (
            f"expected to land on grafana but got '{landed}'"
        )
        assert "/login" not in landed, f"expected to be logged in but got '{landed}'"

        user = json.loads(
            server.succeed(
                f"curl -sf --cacert {caFile} --user testadmin:snakeoilpwd "
                f"'https://{grafanaDomain}/api/users/lookup?loginOrEmail=alice'"
            )
        )
        assert user["isGrafanaAdmin"], f"expected alice to be a grafana admin: {user}"
