def test(subtest, server):
    server.wait_for_unit("postgresql.service")
    server.wait_for_unit("postgresql-set-passwords.service")
    server.wait_for_open_port(5432)

    with subtest("postgresql listens on port 5432"):
        server.succeed("ss -tlnp | grep 5432")

    with subtest("database testuser exists"):
        server.succeed("sudo -u postgres psql -lqt | grep testuser")

    with subtest("user testuser exists"):
        server.succeed("sudo -u postgres psql -c '\\du' | grep testuser")

    with subtest("testuser can authenticate with password and connect to testuser db"):
        server.succeed(
            "PGPASSWORD=testpassword123 psql -h 127.0.0.1 -U testuser -d testuser -c 'SELECT 1'"
        )

    with subtest("postgres superuser password is set from passwordFile"):
        server.succeed(
            "PGPASSWORD=testpassword123 psql -h 127.0.0.1 -U postgres -d postgres -c 'SELECT 1'"
        )
