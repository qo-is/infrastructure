def test(subtest, host):
    host.wait_for_unit("multi-user.target")

    with subtest("IP forwarding is enabled"):
        host.succeed("sysctl -n net.ipv4.ip_forward | grep -q 1")

    with subtest("secret was generated"):
        host.succeed("test -f /dev/shm/microvm-secrets/test-secret/password")

    with subtest("microvm service started"):
        host.wait_for_unit("microvm@test-vm.service")

    with subtest("guest is reachable from host"):
        host.wait_until_succeeds("ping -c1 192.168.100.2", timeout=120)

    with subtest("guest HTTP service is reachable from host"):
        host.wait_until_succeeds("curl -sf http://192.168.100.2:8080/", timeout=120)
