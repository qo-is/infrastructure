def test(subtest, host):
    host.wait_for_unit("multi-user.target")

    with subtest("secret generation service ran successfully"):
        host.wait_for_unit("microvm-secret-test-secret.service")

    with subtest("secret file was generated"):
        host.succeed("test -f /dev/shm/microvm-secrets/test-secret/private")

    with subtest("secret file has correct permissions"):
        host.succeed(
            "stat -c '%a' /dev/shm/microvm-secrets/test-secret/private | grep -q 400"
        )

    with subtest("secret directory has correct permissions"):
        host.succeed("stat -c '%a' /dev/shm/microvm-secrets/test-secret | grep -q 500")

    with subtest("secret file is not empty"):
        host.succeed("test -s /dev/shm/microvm-secrets/test-secret/private")
