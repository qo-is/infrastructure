def test(server, subtest):
    server.wait_for_unit("haproxy.service")
    server.wait_for_unit("telegraf.service")

    with subtest("haproxy-metrics"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c haproxy_"
        )
