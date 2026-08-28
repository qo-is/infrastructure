CA_FILE = "/tmp/pebble-ca.crt"


def download_ca(node, caDomain):
    # Pebble generates its issuing CA at startup, so it can only be trusted at runtime.
    node.wait_until_succeeds(f"curl -sf https://{caDomain}:15000/roots/0 > {CA_FILE}")
    node.succeed(f"curl -sf https://{caDomain}:15000/intermediate-keys/0 >> {CA_FILE}")


def ldapsearch(domain):
    base_dn = "dc=" + domain.replace(".", ",dc=")
    return (
        f"LDAPTLS_CACERT={CA_FILE} ldapsearch -x -o nettimeout=5 "
        f"-H ldaps://{domain}:636 -b '{base_dn}' '(name=idm_admin)'"
    )


def token_status(domain, secret):
    return (
        f"curl -s --cacert {CA_FILE} -o /dev/null -w '%{{http_code}}' -u grafana:{secret} "
        "-d grant_type=authorization_code -d code=bogus "
        f"-d redirect_uri=https://{domain}/login/generic_oauth "
        f"https://{domain}/oauth2/token"
    )


def test(acme, server, client, caDomain, serverDomain, oauth2Secret, subtest):
    acme.wait_for_unit("pebble.service")
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_unit("telegraf.service")

    download_ca(server, caDomain)
    download_ca(client, caDomain)

    with subtest("acme-certificate"):
        # postRun installed the issued certificate where kanidm reads it.
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
            f"curl -sfL --cacert {CA_FILE} https://{serverDomain}/ | grep -ci kanidm"
        )

    with subtest("status"):
        assert (
            server.succeed(
                f"curl -sf --cacert {CA_FILE} https://{serverDomain}/status"
            ).strip()
            == "true"
        )

    with subtest("oauth2-client-provisioned"):
        server.succeed(
            f"curl -sf --cacert {CA_FILE} https://{serverDomain}"
            "/oauth2/openid/grafana/.well-known/openid-configuration"
        )

    with subtest("oauth2-client-secret"):
        # The bogus authorisation code is rejected, but only after the provisioned
        # client secret has been accepted as the client credential.
        accepted = server.succeed(token_status(serverDomain, oauth2Secret)).strip()
        assert accepted == "400", (
            f"expected 400 for the provisioned secret, got {accepted}"
        )

        rejected = server.succeed(token_status(serverDomain, "wrongSecret")).strip()
        assert rejected == "401", f"expected 401 for a wrong secret, got {rejected}"

    with subtest("ldaps-localhost"):
        server.succeed(ldapsearch(serverDomain))

    with subtest("ldaps-port-isolation"):
        client.fail(ldapsearch(serverDomain))

    with subtest("telegraf-metrics"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c x509_cert"
        )
