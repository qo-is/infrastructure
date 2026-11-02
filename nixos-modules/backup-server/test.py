start_all()  # noqa: F821


def test(server, subtest):
    snapshot = "/mnt/data/backup/.snapshots/1/snapshot"

    with subtest("backup-subvolume"):
        server.wait_for_unit("multi-user.target")
        server.succeed("mkfs.btrfs /dev/vdb")
        server.succeed("mkdir -p /mnt/data && mount /dev/vdb /mnt/data")
        server.succeed("btrfs subvolume create /mnt/data/backup")
        server.succeed("btrfs subvolume create /mnt/data/backup/.snapshots")
        server.succeed("systemd-tmpfiles --create")
        server.succeed("echo data > /mnt/data/backup/file")

    with subtest("snapshot-created-read-only"):
        server.succeed("systemctl start --wait snapper-timeline.service")
        server.succeed(f"btrfs property get -ts {snapshot} ro | grep -c ro=true")
        server.succeed(f"grep -c data {snapshot}/file")

    with subtest("cleanup-keeps-recent-snapshots"):
        server.succeed("systemctl start --wait snapper-cleanup.service")
        server.succeed(f"test -d {snapshot}")

    with subtest("snapshots-out-of-borg-reach"):
        server.succeed("stat -c %a /mnt/data/backup/.snapshots | grep -c '^750$'")
        server.fail("sudo -u borg ls /mnt/data/backup/.snapshots")
        server.fail(f"sudo -u borg btrfs subvolume delete {snapshot}")

    with subtest("snapshot-job-monitored"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics"
            " | grep -c '^systemd_job_success{.*name=\"snapper-timeline.service\"} 1'"
        )

    with subtest("cleanup-removes-snapshots-after-a-month"):
        server.succeed("date -s \"$(date -d '+32 days')\"")
        server.succeed("systemctl start --wait snapper-cleanup.service")
        server.fail(f"test -e {snapshot}")
