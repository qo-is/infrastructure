def test(subtest, server):
    server.wait_for_unit("jellyfin.service")
    server.wait_for_open_port(8096)

    with subtest("jellyfin HTTP endpoint responds"):
        server.succeed("curl -sf http://localhost:8096/health")
