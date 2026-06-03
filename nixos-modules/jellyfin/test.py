start_all()  # noqa: F821


def test(server, jellyfinDomain, subtest):
    with subtest("jellyfin-ready"):
        server.wait_for_unit("jellyfin.service")
        server.wait_for_open_port(8096)

    with subtest("jellyfin-health"):
        server.wait_until_succeeds(
            "curl -s http://localhost:8096/System/Info/Public | grep -c ServerName"
        )

    with subtest("nginx-https"):
        server.wait_for_unit("nginx.service")
        server.wait_until_succeeds(
            f"curl -s https://{jellyfinDomain}/System/Info/Public | grep -c ServerName"
        )

    with subtest("api-key-injected"):
        server.wait_for_unit("jellyfin-api-key.service")
