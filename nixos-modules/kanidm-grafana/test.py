def test(server, grafanaDomain, kanidmDomain, subtest):
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("grafana.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(3000)

    with subtest("oauth2-client-provisioned"):
        # The snakeoil certificate only covers grafanaDomain and certificate handling is
        # covered by the kanidm module test, so skip verification here.
        server.wait_until_succeeds(
            f"curl -sfk https://{kanidmDomain}"
            "/oauth2/openid/grafana/.well-known/openid-configuration"
        )

    with subtest("grafana-oauth-redirect"):
        redirect_url = (
            f"curl -s -o /dev/null -w '%{{redirect_url}}' "
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
