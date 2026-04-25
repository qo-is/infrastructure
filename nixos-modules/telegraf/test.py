start_all()  # noqa: F821


def test(server, subtest):
    with subtest("telegraf-ready"):
        server.wait_for_unit("telegraf.service")
        server.wait_for_open_port(9273)

    with subtest("metrics-exposed"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c cpu_usage_idle"
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c mem_available"
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c net_bytes_recv"
        )

    with subtest("monitoring-http-response"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c http_response_result_code"
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c http_response_response_string_match"
        )

    with subtest("monitoring-ping"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c ping_average_response_ms"
        )
