start_all()  # noqa: F821

SSH = "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"


def test(server, client, subtest):
    server.wait_for_unit("sshd.service")
    server.wait_for_open_port(22)

    with subtest("sshd-preauth-noise-filtered"):
        client.fail(f"{SSH} nosuchuser@server true")
        client.succeed(f"{SSH} -i /etc/ssh-test-key root@server true")
        server.wait_until_succeeds(
            "journalctl -u sshd.service -g 'Accepted publickey for root'"
        )
        server.fail("journalctl -u sshd.service -g nosuchuser")
