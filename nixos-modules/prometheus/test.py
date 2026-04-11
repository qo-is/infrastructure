def test(server, subtest):
    server.wait_for_unit("prometheus.service")
    server.wait_for_open_port(9090)

    metrics = server.succeed("curl -s http://localhost:9090/metrics")
    assert "prometheus_build_info" in metrics, (
        f"expected prometheus_build_info in prometheus response but was not found in '{metrics}'"
    )
