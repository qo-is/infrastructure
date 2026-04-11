start_all()  # noqa: F821


def test(server, subtest):
    with subtest("telegraf-ready"):
        server.wait_for_unit("telegraf.service")
        server.wait_for_open_port(9273)

    with subtest("metrics-exposed"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -q cpu_usage_idle",
            timeout=120,
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -q mem_available", timeout=120
        )
