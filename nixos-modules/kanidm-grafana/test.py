CA_FILE = "/tmp/pebble-ca.crt"


def download_ca(node, caDomain):
    # Pebble generates its issuing CA at startup, so it can only be trusted at runtime.
    node.wait_until_succeeds(f"curl -sf https://{caDomain}:15000/roots/0 > {CA_FILE}")
    node.succeed(f"curl -sf https://{caDomain}:15000/intermediate-keys/0 >> {CA_FILE}")


def test(acme, server, caDomain, grafanaDomain, kanidmDomain, subtest):
    acme.wait_for_unit("pebble.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("grafana.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(3000)

    download_ca(server, caDomain)

    with subtest("oauth2-client-provisioned"):
        server.wait_until_succeeds(
            f"curl -sf --cacert {CA_FILE} https://{kanidmDomain}"
            "/oauth2/openid/grafana/.well-known/openid-configuration"
        )

    with subtest("grafana-oauth-redirect"):
        redirect_url = (
            f"curl -s --cacert {CA_FILE} -o /dev/null -w '%{{redirect_url}}' "
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
