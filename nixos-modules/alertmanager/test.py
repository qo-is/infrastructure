def test(server, subtest):
    server.wait_for_unit("prometheus.service")
    server.wait_for_unit("alertmanager.service")
    server.wait_for_open_port(9093)

    with subtest("alertmanager-discovered"):
        server.wait_until_succeeds(
            "curl -s 'http://localhost:9090/api/v1/query?query=prometheus_notifications_alertmanagers_discovered%3E%3D1' | grep -c '\"result\":\\[{'",
            timeout=120,
        )

    with subtest("rules-loaded"):
        rules = server.succeed("curl -s http://localhost:9090/api/v1/rules")
        assert "SystemdServiceFailed" in rules, (
            f"expected SystemdServiceFailed rule in prometheus rules but was not found in '{rules}'"
        )
