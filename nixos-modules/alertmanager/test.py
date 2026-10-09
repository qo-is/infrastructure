def test(server, subtest):
    server.wait_for_unit("prometheus.service")
    server.wait_for_unit("alertmanager.service")
    server.wait_for_open_port(9093)

    with subtest("alertmanager-discovered"):
        server.wait_until_succeeds(
            "curl -s 'http://localhost:9090/api/v1/query?query=prometheus_notifications_alertmanagers_discovered%3E%3D1' | grep -c '\"result\":\\[{'",
            timeout=120,
        )

    with subtest("alertmanager-served-under-route-prefix"):
        server.succeed("curl -sf http://localhost:9093/alertmanager/-/ready")
        alertmanagers = server.succeed(
            "curl -sf http://localhost:9090/api/v1/alertmanagers"
        )
        assert "localhost:9093/alertmanager/api/v2/alerts" in alertmanagers, (
            f"expected prometheus to target the alertmanager route prefix but got '{alertmanagers}'"
        )

    with subtest("rules-loaded"):
        rules = server.succeed("curl -s http://localhost:9090/api/v1/rules")
        assert "SystemdServiceFailed" in rules, (
            f"expected SystemdServiceFailed rule in prometheus rules but was not found in '{rules}'"
        )
