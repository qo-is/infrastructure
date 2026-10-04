def download_ca(node, caDomain, caFile):
    # Pebble generates its issuing CA at startup, so it can only be trusted at runtime.
    node.wait_until_succeeds(f"curl -sf https://{caDomain}:15000/roots/0 > {caFile}")
    node.succeed(f"curl -sf https://{caDomain}:15000/intermediate-keys/0 >> {caFile}")


def ldapsearch(domain, caFile):
    base_dn = "dc=" + domain.replace(".", ",dc=")
    return (
        f"LDAPTLS_CACERT={caFile} ldapsearch -x -o nettimeout=5 "
        f"-H ldaps://{domain}:636 -b '{base_dn}' '(name=idm_admin)'"
    )


def token_status(domain, caFile, secret):
    return (
        f"curl -s --cacert {caFile} -o /dev/null -w '%{{http_code}}' -u grafana:{secret} "
        "-d grant_type=authorization_code -d code=bogus "
        f"-d redirect_uri=https://{domain}/login/generic_oauth "
        f"https://{domain}/oauth2/token"
    )


def kanidm_cli(command):
    return (
        "KANIDM_URL=https://localhost:8443 KANIDM_ACCEPT_INVALID_CERTS=true "
        f"kanidm {command}"
    )


def test(
    acme,
    server,
    client,
    caDomain,
    caFile,
    serverDomain,
    oauth2Secret,
    idmAdminPassword,
    mailRecipient,
    subtest,
):
    acme.wait_for_unit("pebble.service")
    acme.wait_for_unit("mailpit-relay.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_unit("telegraf.service")

    download_ca(server, caDomain, caFile)
    download_ca(client, caDomain, caFile)

    with subtest("acme-certificate"):
        assert (
            server.succeed("stat -c '%U:%G %a' /var/lib/kanidm/fullchain.pem").strip()
            == "kanidm:kanidm 400"
        )
        assert (
            server.succeed("stat -c '%U:%G %a' /var/lib/kanidm/key.pem").strip()
            == "kanidm:kanidm 400"
        )

    with subtest("web-ui"):
        server.wait_until_succeeds(
            f"curl -sfL --cacert {caFile} https://{serverDomain}/ | grep -ci kanidm"
        )

    with subtest("status"):
        assert (
            server.succeed(
                f"curl -sf --cacert {caFile} https://{serverDomain}/status"
            ).strip()
            == "true"
        )

    with subtest("oauth2-client-provisioned"):
        server.succeed(
            f"curl -sf --cacert {caFile} https://{serverDomain}"
            "/oauth2/openid/grafana/.well-known/openid-configuration"
        )

    with subtest("oauth2-client-secret"):
        # The bogus authorisation code is rejected, but only after the provisioned
        # client secret has been accepted as the client credential.
        accepted = server.succeed(
            token_status(serverDomain, caFile, oauth2Secret)
        ).strip()
        assert accepted == "400", (
            f"expected 400 for the provisioned secret, got {accepted}"
        )

        rejected = server.succeed(
            token_status(serverDomain, caFile, "wrongSecret")
        ).strip()
        assert rejected == "401", f"expected 401 for a wrong secret, got {rejected}"

    with subtest("sysadmin-entry-manager"):
        server.succeed(
            f"KANIDM_PASSWORD={idmAdminPassword} "
            + kanidm_cli("login --name idm_admin")
        )
        server.succeed(kanidm_cli("person create alice Alice --name idm_admin"))
        server.succeed(kanidm_cli("group add-members sysadmin alice --name idm_admin"))
        assert "alice" in server.succeed(
            kanidm_cli("group list-members sysadmin --name idm_admin")
        )
        assert "sysadmin" in server.succeed(
            kanidm_cli("group list-members idm_admins --name idm_admin")
        )

    with subtest("entry-manager-idempotent"):
        server.succeed("systemctl restart kanidm.service")
        server.wait_for_unit("kanidm.service")
        managed = server.succeed(
            "journalctl -u kanidm.service"
            " | grep -c 'kanidm entry managers: managing sysadmin'"
        ).strip()
        assert managed == "1", f"expected a single entry manager change, got {managed}"

    with subtest("mail-sender-account"):
        server.wait_for_unit("kanidm-mail-sender.service")
        server.succeed(
            f"KANIDM_PASSWORD={idmAdminPassword} "
            + kanidm_cli("login --name idm_admin")
        )
        senders = server.succeed(
            kanidm_cli("group list-members idm_message_senders --name idm_admin")
        )
        assert "mail-sender@" in senders, (
            f"mail-sender is not a message sender:\n{senders}"
        )
        assert (
            server.succeed(
                "stat -c '%U:%G %a' /var/lib/kanidm/mail-sender-token"
            ).strip()
            == "kanidm:kanidm 600"
        )

    with subtest("mail-sender-token-idempotent"):
        token = server.succeed("sha256sum /var/lib/kanidm/mail-sender-token")
        server.succeed("systemctl restart kanidm-mail-sender-token.service")
        assert token == server.succeed("sha256sum /var/lib/kanidm/mail-sender-token")
        generated = server.succeed(
            "journalctl -u kanidm-mail-sender-token.service"
            " | grep -c 'kanidm mail sender: generating token'"
        ).strip()
        assert generated == "1", f"expected a single token generation, got {generated}"
        added = server.succeed(
            "journalctl -u kanidm-mail-sender-token.service"
            " | grep -c 'kanidm mail sender: adding mail-sender'"
        ).strip()
        assert added == "1", f"expected a single membership change, got {added}"
        server.wait_for_unit("kanidm-mail-sender.service")

    with subtest("mail-sender-delivers-reset-token"):
        server.succeed(
            kanidm_cli("person credential send-reset-token bob --name idm_admin")
        )
        acme.wait_until_succeeds(
            "curl -sf http://localhost:8025/api/v1/messages"
            f" | grep -c '{mailRecipient}'"
        )
        server.wait_until_succeeds(
            kanidm_cli("system message-queue list --name idm_admin")
            + " | grep -c 'sent_at: *[0-9]'"
        )

    with subtest("ldaps-localhost"):
        server.succeed(ldapsearch(serverDomain, caFile))

    with subtest("ldaps-port-isolation"):
        client.fail(ldapsearch(serverDomain, caFile))

    with subtest("telegraf-kanidm-status"):
        # Go caches the trust store on the first handshake, so telegraf has to start
        # after the CA it is pointed at exists.
        server.succeed("systemctl restart telegraf.service")
        metrics = server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics"
            f" | grep 'http_response.*{serverDomain}/status'"
        )
        assert 'result="success"' in metrics, (
            f"kanidm's status endpoint was not probed successfully:\n{metrics}"
        )
