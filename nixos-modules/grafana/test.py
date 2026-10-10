import json

start_all()  # noqa: F821


def test(server, client, serverDomain, subtest):
    with subtest("grafana-ready"):
        server.wait_for_unit("grafana.service")
        server.wait_for_open_port(3000)

    with subtest("authenticated-access"):
        result = client.succeed(
            f"curl --basic --user testadmin:snakeoilpwd https://{serverDomain}/api/org"
        )
        org = json.loads(result)
        assert org.get("statusCode") is None, (
            f"expected no value for statusCode but was '{org.get('statusCode')}'"
        )
        assert org.get("name") == "Main Org.", (
            f"expected org name of 'Main Org.' but was '{org.get('name')}'"
        )

    with subtest("unauthenticated-access"):
        result = client.succeed(f"curl https://{serverDomain}/api/org")
        error = json.loads(result)
        assert error.get("statusCode") == 401, (
            f"expected statusCode to be '401' but was '{error.get('statusCode')}'"
        )
        assert error.get("messageId") == "auth.unauthorized", (
            f"expected messageId to be 'auth.unauthorized' but was '{error.get('messageId')}'"
        )

    with subtest("http-redirect"):
        result = client.succeed(
            f"curl -s -o /dev/null -w '%{{http_code}}' http://{serverDomain}/api/org"
        )
        assert result.strip() == "301", f"expected 301 redirect, got {result}"

    with subtest("port-isolation"):
        client.fail("curl --max-time 5 https://192.168.1.2:3000/api/org")

    with subtest("postgresql-initialized"):
        server.succeed("sudo -u grafana psql grafana -c '\\dt' | grep -c dashboard")

    with subtest("prometheus-datasource-provisioned"):
        result = client.succeed(
            f"curl --basic --user testadmin:snakeoilpwd https://{serverDomain}/api/datasources"
        )
        datasources = json.loads(result)
        prometheus_ds = [ds for ds in datasources if ds.get("type") == "prometheus"]
        assert len(prometheus_ds) == 1, (
            f"expected exactly 1 prometheus datasource but found {len(prometheus_ds)}"
        )
        assert prometheus_ds[0].get("isDefault") is True, (
            f"expected prometheus datasource to be default but isDefault was '{prometheus_ds[0].get('isDefault')}'"
        )
        assert prometheus_ds[0].get("name") == "Prometheus", (
            f"expected datasource name 'Prometheus' but was '{prometheus_ds[0].get('name')}'"
        )

    with subtest("loki-datasource-provisioned"):
        result = client.succeed(
            f"curl --basic --user testadmin:snakeoilpwd https://{serverDomain}/api/datasources"
        )
        datasources = json.loads(result)
        loki_ds = [ds for ds in datasources if ds.get("type") == "loki"]
        assert len(loki_ds) == 1, (
            f"expected exactly 1 loki datasource but found {len(loki_ds)}"
        )
        assert loki_ds[0].get("name") == "Loki", (
            f"expected datasource name 'Loki' but was '{loki_ds[0].get('name')}'"
        )

    with subtest("alertmanager-datasource-provisioned"):
        result = client.succeed(
            f"curl --basic --user testadmin:snakeoilpwd https://{serverDomain}/api/datasources"
        )
        datasources = json.loads(result)
        alertmanager_ds = [ds for ds in datasources if ds.get("type") == "alertmanager"]
        assert len(alertmanager_ds) == 1, (
            f"expected exactly 1 alertmanager datasource but found {len(alertmanager_ds)}"
        )
        assert alertmanager_ds[0].get("name") == "Alertmanager", (
            f"expected datasource name 'Alertmanager' but was '{alertmanager_ds[0].get('name')}'"
        )

    with subtest("alertmanager-datasource-reachable"):
        server.wait_for_unit("alertmanager.service")
        uid = alertmanager_ds[0]["uid"]
        result = client.succeed(
            f"curl --fail --basic --user testadmin:snakeoilpwd https://{serverDomain}/api/alertmanager/{uid}/api/v2/status"
        )
        status = json.loads(result)
        assert status.get("cluster") is not None, (
            f"expected alertmanager status with cluster info but got '{status}'"
        )

    with subtest("e2e-login"):
        client.succeed(f"grafana-selenium-test {serverDomain}")
