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
        server.succeed("sudo -u grafana psql grafana -c '\\dt' | grep -q dashboard")
