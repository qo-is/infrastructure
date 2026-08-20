def test(backend, client, server, subtest):
    backend.wait_for_unit("nginx.service")
    server.wait_for_unit("haproxy.service")
    server.wait_for_unit("telegraf.service")

    with subtest("haproxy-metrics"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c haproxy_"
        )

    with subtest("real-client-ip-preserved-through-proxy-protocol"):
        client.wait_until_succeeds(
            "curl -s -H 'Host: test.example.com' http://192.168.1.3/ | grep -c '^192.168.1.2$'"
        )
