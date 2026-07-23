start_all()  # noqa: F821


def test(subtest, client, server):
    def ssh_is_up(_) -> bool:
        status, _ = client.execute("nc -z 192.168.1.2 2222")
        return status == 0

    client.wait_for_unit("network.target")
    with client.nested("waiting for initrd SSH server to come up"):
        retry(ssh_is_up)  # noqa: F821

    ssh_cmd = "ssh -i /etc/sshKey -o UserKnownHostsFile=/etc/knownHosts -p 2222 root@192.168.1.2"

    with subtest(
        "authorized key is forced to run systemctl default, not arbitrary commands"
    ):
        output = client.succeed(f"{ssh_cmd} 'echo should-not-print'")
        assert "should-not-print" not in output, (
            "command= restriction on the authorized key was not enforced"
        )

    server.switch_root()
    server.wait_for_unit("multi-user.target")
