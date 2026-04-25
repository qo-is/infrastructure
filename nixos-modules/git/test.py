def test(server, serverDomain, subtest):
    server.wait_for_unit("forgejo.service")
    server.wait_for_unit("telegraf.service")

    with subtest("forgejo-metrics"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c gitea_"
        )
