def kanidm_cli(command):
    return (
        "KANIDM_URL=https://localhost:8443 KANIDM_ACCEPT_INVALID_CERTS=true "
        f"kanidm {command} --name idm_admin"
    )


def token_status(kanidmDomain, caFile, secret):
    return (
        f"curl -s --cacert {caFile} -o /dev/null -w '%{{http_code}}' -u dummy:{secret} "
        "-d grant_type=authorization_code -d code=bogus "
        "-d redirect_uri=https://dummy.test/oauth2/callback "
        f"https://{kanidmDomain}/oauth2/token"
    )


def test(
    acme,
    server,
    caFile,
    kanidmDomain,
    idmAdminPassword,
    oauth2Secret,
    subtest,
    **_,
):
    acme.wait_for_unit("pebble.service")
    server.wait_for_unit("pebble-ca.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("nginx.service")

    with subtest("oauth2-client-provisioned"):
        server.wait_until_succeeds(
            f"curl -sf --cacert {caFile} https://{kanidmDomain}"
            "/oauth2/openid/dummy/.well-known/openid-configuration"
        )

    with subtest("secret-copies"):
        for consumer, owner in [("kanidm", "kanidm"), ("dummy", "dummy")]:
            path = f"/run/secrets/kanidm/oauth2/dummy/{consumer}"
            stat = server.succeed(f"stat -L -c '%U %a' {path}").strip()
            assert stat == f"{owner} 400", (
                f"expected {owner} 400 for {path}, got {stat}"
            )
            assert server.succeed(f"cat {path}") == oauth2Secret

        server.wait_for_unit("dummy.service")

        # The bogus authorisation code is rejected, but only after the secret kanidm read
        # from its copy has been accepted as the client credential.
        accepted = server.succeed(token_status(kanidmDomain, caFile, oauth2Secret))
        assert accepted == "400", (
            f"expected 400 for the provisioned secret, got {accepted}"
        )
        rejected = server.succeed(token_status(kanidmDomain, caFile, "wrongSecret"))
        assert rejected == "401", f"expected 401 for a wrong secret, got {rejected}"

    with subtest("groups-provisioned"):
        server.succeed(f"KANIDM_PASSWORD={idmAdminPassword} " + kanidm_cli("login"))
        members = server.succeed(kanidm_cli("group list-members dummy.access"))
        for group in ["sysadmin", "dummy-users"]:
            assert f"{group}@" in members, (
                f"expected {group} in dummy.access, got:\n{members}"
            )
