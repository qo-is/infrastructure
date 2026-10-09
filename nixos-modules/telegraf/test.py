start_all()  # noqa: F821


def test(server, subtest):
    with subtest("telegraf-ready"):
        server.wait_for_unit("telegraf.service")
        server.wait_for_open_port(9273)

    with subtest("metrics-exposed"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c cpu_usage_idle"
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c mem_available"
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c net_bytes_recv"
        )

    with subtest("monitoring-http-response"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c http_response_result_code"
        )
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c http_response_response_string_match"
        )

    with subtest("monitoring-ping"):
        server.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c ping_average_response_ms"
        )

    with subtest("monitoring-build-status"):
        metric = "curl -s http://localhost:9273/metrics | grep -c "
        server.wait_until_succeeds(
            metric + "'^forgejo_build_status_value{.*branch=\"main\".*} 1$'"
        )
        server.wait_until_succeeds(
            metric + "'^forgejo_build_status_value{.*branch=\"green\".*} 0$'"
        )
        server.succeed(
            metric
            + "'^forgejo_build_status_last_success_timestamp{.*branch=\"green\".*} 1.791483473e+09$'"
        )
        server.fail(
            metric + "'^forgejo_build_status_last_success_timestamp{.*branch=\"main\"'"
        )
        server.succeed(
            "curl -s http://localhost:9273/metrics"
            " | grep '^forgejo_build_status_value' | grep -cv 'state='"
        )

    with subtest("btrfs"):
        server.succeed("mkfs.btrfs --label test-data /dev/vdb")
        server.succeed("mkdir -p /mnt/btrfs && mount /dev/vdb /mnt/btrfs")
        metric = "curl -s http://localhost:9273/metrics | grep -c "
        server.wait_until_succeeds(
            metric
            + '\'^btrfs_device_errors_corruption_errs{.*devid="1".*label="test-data".*} 0$\''
        )
        server.succeed(
            metric + "'^btrfs_space_unallocated{.*label=\"test-data\".*} [1-9]'"
        )
        server.succeed(
            metric + "'^btrfs_allocation_bytes_used{.*type=\"metadata\".*} [0-9]'"
        )
        server.succeed(metric + "'^btrfs_commits_commits{.*label=\"test-data\".*}'")

    with subtest("fwupd"):
        metric = "curl -s http://localhost:9273/metrics | grep -c "
        server.wait_until_succeeds(metric + "'^fwupd_updates_devices{.*} 0$'")
        server.succeed(
            metric + "'^systemd_job_success{.*name=\"fwupd-refresh.service\"}'"
        )

    with subtest("periodic-jobs"):
        metric = "curl -s http://localhost:9273/metrics | grep -c "
        server.wait_until_succeeds(
            metric + "'^systemd_job_success{.*name=\"demo-job.service\"} 0'"
        )
        server.succeed("systemctl start demo-job.service")
        server.fail("systemctl start failing-job.service")
        server.wait_until_succeeds(
            metric + "'^systemd_job_success{.*name=\"demo-job.service\"} 1'"
        )
        server.succeed(
            metric
            + "'^systemd_job_last_success_timestamp{.*name=\"demo-job.service\"}'"
        )
        server.succeed(
            metric + "'^systemd_job_success{.*name=\"failing-job.service\"} 0'"
        )
