LDAP_ENV = "LDAPTLS_CACERT=/etc/ssl/certs/ca-certificates.crt"


def ldapsearch(domain):
    return (
        f"{LDAP_ENV} ldapsearch -x -o nettimeout=5 "
        f"-H ldaps://{domain}:636 -b 'dc=acme,dc=test' '(name=idm_admin)'"
    )


def token_status(domain, secret):
    return (
        f"curl -s -o /dev/null -w '%{{http_code}}' -u grafana:{secret} "
        "-d grant_type=authorization_code -d code=bogus "
        f"-d redirect_uri=https://{domain}/login/generic_oauth "
        f"https://{domain}/oauth2/token"
    )


def test(server, client, serverDomain, oauth2Secret, subtest):
    server.wait_for_unit("kanidm.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_unit("telegraf.service")

    with subtest("web-ui"):
        server.wait_until_succeeds(
            f"curl -sfL https://{serverDomain}/ | grep -ci kanidm"
        )

    with subtest("status"):
        assert (
            server.succeed(f"curl -sf https://{serverDomain}/status").strip() == "true"
        )

    with subtest("oauth2-client-provisioned"):
        server.succeed(
            f"curl -sf https://{serverDomain}"
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
