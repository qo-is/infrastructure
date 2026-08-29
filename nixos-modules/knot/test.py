def test(primary, secondary, primaryIp, secondaryIp, subtest):
    primary.wait_for_unit("knot.service")
    primary.wait_for_open_port(53)

    def kdig(machine, args):
        return machine.succeed(f"kdig +tcp @127.0.0.1 {args}")

    with subtest("records generated from qois.meta are served"):
        assert "10.250.0.2" in kdig(primary, "+short lindberg.backplane.net.qo.is. A")

    with subtest("explicitly declared records are served"):
        assert "149.126.4.120" in kdig(primary, "+short mx.qo.is. A")
        assert "lindberg.riedbach-ext.net.qo.is." in kdig(
            primary, "+short git.qo.is. CNAME"
        )
        assert "spf.protection.cyon.net" in kdig(primary, "+short qo.is. TXT")

    with subtest("zone is signed"):
        assert "RRSIG" in kdig(primary, "+dnssec qo.is. SOA")
        assert "DNSKEY" in kdig(primary, "qo.is. DNSKEY")
        assert "NSEC3PARAM" in kdig(primary, "qo.is. NSEC3PARAM")

    with subtest("ds record is published for the registrar"):
        primary.wait_until_succeeds(
            "kdig +tcp +short @127.0.0.1 qo.is. CDS | grep -c ."
        )

    with subtest("secondary transfers the signed zone"):
        secondary.wait_for_unit("knot.service")
        secondary.wait_until_succeeds(
            "kdig +tcp +short @127.0.0.1 mx.qo.is. A | grep -c 149.126.4.120"
        )
        assert "RRSIG" in kdig(secondary, "+dnssec qo.is. SOA")

    with subtest("transfers are refused from undeclared secondaries"):
        primary.fail(f"kdig +tcp @{primaryIp} qo.is. AXFR | grep -c 'mx.qo.is'")

    with subtest("rate limiting drops floods from unlisted clients"):
        secondary.succeed(
            f"for i in $(seq 20); do"
            f" kdig +short +timeout=1 +retry=0 @{primaryIp} qo.is. SOA || true;"
            f" done"
        )
        # Counters only show up once the limiter has actually acted on a query.
        assert primary.succeed("knotc stats mod-rrl").strip()

    with subtest("knot-metrics"):
        primary.wait_for_unit("telegraf.service")
        primary.wait_until_succeeds(
            "curl -s http://localhost:9273/metrics | grep -c knot_"
        )
