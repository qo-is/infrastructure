import json
import time

start_all()  # noqa: F821


def test(server, subtest):
    with subtest("loki-ready"):
        server.wait_for_unit("loki.service")
        server.wait_for_open_port(3100)

    with subtest("push-and-query"):
        payload = json.dumps(
            {
                "streams": [
                    {
                        "stream": {"job": "test"},
                        "values": [[str(time.time_ns()), "qois loki test log line"]],
                    }
                ]
            }
        )
        server.succeed(
            f"curl --fail --json '{payload}' http://localhost:3100/loki/api/v1/push"
        )
        server.wait_until_succeeds(
            "logcli query --no-labels '{job=\"test\"}' | grep -c 'qois loki test log line'"
        )

    with subtest("metrics-exposed"):
        server.succeed(
            "curl -sf http://localhost:3100/metrics | grep -c loki_build_info"
        )
