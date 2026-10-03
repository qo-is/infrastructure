import json
import shlex


def kanidm_cli(command):
    return (
        "KANIDM_URL=https://localhost:8443 KANIDM_ACCEPT_INVALID_CERTS=true "
        f"kanidm {command} --name idm_admin"
    )


def psql(query):
    return f"runuser -u postgres -- psql -d forgejo -tA -c {shlex.quote(query)}"


def forgejo_cli(command):
    return (
        "runuser -u forgejo -- env GITEA_WORK_DIR=/var/lib/forgejo "
        f"forgejo admin {command}"
    )


def is_owner(server, username):
    count = server.succeed(
        psql(
            "SELECT count(*) FROM team_user tu "
            "JOIN team t ON t.id = tu.team_id "
            'JOIN "user" o ON o.id = t.org_id '
            'JOIN "user" u ON u.id = tu.uid '
            "WHERE o.lower_name = 'qo.is' AND t.lower_name = 'owners' "
            f"AND u.lower_name = '{username}'"
        )
    ).strip()
    return count == "1"


def oidc_login(server, gitDomain, username, password):
    landed = server.succeed(
        f"kanidm-oidc-login https://{gitDomain}/user/oauth2/kanidm "
        f"{username} {password} $(mktemp)"
    ).strip()
    assert landed.startswith(f"https://{gitDomain}/"), (
        f"expected to land on forgejo but got '{landed}'"
    )
    assert "/user/" not in landed, f"expected to be logged in but got '{landed}'"


def assert_redirects_to_kanidm(server, caFile, gitDomain, kanidmDomain):
    redirect = server.succeed(
        f"curl -s --cacert {caFile} -o /dev/null -w '%{{redirect_url}}' "
        f"https://{gitDomain}/user/oauth2/kanidm"
    )
    assert redirect.startswith(f"https://{kanidmDomain}/ui/oauth2"), (
        f"expected a redirect to the kanidm authorisation endpoint but got '{redirect}'"
    )
    assert "client_id=forgejo" in redirect, (
        f"expected client_id=forgejo in '{redirect}'"
    )
    assert "code_challenge=" in redirect, (
        f"expected a PKCE code_challenge in '{redirect}'"
    )


def test(
    acme,
    server,
    caFile,
    gitDomain,
    kanidmDomain,
    idmAdminPassword,
    subtest,
    **_,
):
    acme.wait_for_unit("pebble.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("forgejo.service")
    server.wait_for_unit("nginx.service")

    with subtest("oauth2-client-provisioned"):
        server.succeed(
            f"curl -sf --cacert {caFile} https://{kanidmDomain}"
            "/oauth2/openid/forgejo/.well-known/openid-configuration"
        )

    with subtest("forgejo-oauth-redirect"):
        assert_redirects_to_kanidm(server, caFile, gitDomain, kanidmDomain)

    with subtest("source-config"):
        source = json.loads(
            server.succeed(psql("SELECT cfg FROM login_source WHERE name = 'kanidm'"))
        )
        assert source["Provider"] == "openidConnect", source
        assert source["ClientID"] == "forgejo", source
        assert source["GroupClaimName"] == "groups", source
        assert source["AdminGroup"] == "sysadmin", source
        assert json.loads(source["GroupTeamMap"]) == {
            "forgejo-qois": {"qo.is": ["Owners"]}
        }, source
        assert source["GroupTeamMapRemoval"], source

        server.succeed(f"KANIDM_PASSWORD={idmAdminPassword} " + kanidm_cli("login"))
        members = server.succeed(kanidm_cli("group list-members forgejo-qois"))
        assert "sysadmin@" in members, (
            f"expected sysadmin in forgejo-qois, got:\n{members}"
        )

    with subtest("source-update-idempotent"):
        server.succeed("systemctl restart forgejo.service")
        server.wait_for_unit("forgejo.service")
        sources = server.succeed(
            psql("SELECT count(*) FROM login_source WHERE name = 'kanidm'")
        ).strip()
        assert sources == "1", f"expected a single kanidm login source, got {sources}"
        server.fail(
            "journalctl -u forgejo.service | grep 'could not update the kanidm login source'"
        )
        login = server.succeed(
            f"curl -sf --cacert {caFile} https://{gitDomain}/user/login"
        )
        assert login.count('href="/user/oauth2/kanidm"') == 1, (
            "expected exactly one kanidm link on the login page"
        )
        assert_redirects_to_kanidm(server, caFile, gitDomain, kanidmDomain)

    with subtest("login-roles-mapped"):
        server.succeed(
            forgejo_cli(
                "user create --admin --username localadmin --password snakeoilpwd "
                "--email localadmin@localhost --must-change-password=false"
            )
        )
        server.succeed(
            f"curl -sf --cacert {caFile} --user localadmin:snakeoilpwd "
            "-H 'Content-Type: application/json' -d '{\"username\": \"qo.is\"}' "
            f"https://{gitDomain}/api/v1/orgs"
        )

        server.succeed("kanidm-test-person alice snakeoilAlicePassword sysadmin")
        oidc_login(server, gitDomain, "alice", "snakeoilAlicePassword")
        is_admin = server.succeed(
            psql("SELECT is_admin FROM \"user\" WHERE lower_name = 'alice'")
        ).strip()
        assert is_admin == "t", f"expected alice to be a site admin, got '{is_admin}'"
        assert is_owner(server, "alice"), "expected alice in qo.is/Owners"

    with subtest("login-team-removal"):
        server.succeed(
            "kanidm-test-person bob snakeoilBobPassword forgejo-users forgejo-qois"
        )
        oidc_login(server, gitDomain, "bob", "snakeoilBobPassword")
        assert is_owner(server, "bob"), "expected bob in qo.is/Owners"

        server.succeed(kanidm_cli("group remove-members forgejo-qois bob"))
        oidc_login(server, gitDomain, "bob", "snakeoilBobPassword")
        assert not is_owner(server, "bob"), "expected bob removed from qo.is/Owners"
