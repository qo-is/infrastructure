def test(server, serverDomain, subtest):
    server.wait_for_unit("vaultwarden.service")

    with subtest("vaultwarden is running"):
        server.wait_until_succeeds(
            f"curl -s https://{serverDomain} | grep -i -c vaultwarden"
        )
