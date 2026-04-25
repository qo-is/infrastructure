def test(server, subtest):
    server.wait_for_unit("postgresql.service")
    server.wait_for_unit("telegraf.service")

    with subtest("postgresql-metrics"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -q postgresql_",
        )
