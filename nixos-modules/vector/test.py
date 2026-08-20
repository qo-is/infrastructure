start_all()  # noqa: F821


def test(server, client, subtest):
    with subtest("loki-ready"):
        server.wait_for_unit("loki.service")
        server.wait_for_open_port(3100)

    with subtest("vector-ready"):
        client.wait_for_unit("vector.service")

    with subtest("log-shipped-to-loki"):
        client.succeed(
            "logger -t qois-vector-test 'qois vector integration test log line'"
        )
        server.wait_until_succeeds(
            "logcli query --no-labels '{host=\"client\"}' "
            "| grep -c 'qois vector integration test log line'"
        )
