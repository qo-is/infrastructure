# Loki

Central log aggregation, fed by [`qois.vector`](../vector) agents running on every host.
Reachable only over the `backplane` network (no public exposure, unlike Grafana).

## Querying logs

- Grafana Explore at https://monitoring.qo.is/explore, datasource "Loki".
- `logcli` on the Loki host itself, e.g.
  `logcli query '{host="cyprianspitz"}' --limit 100`.

## Storage

Logs are stored on local disk (`/var/lib/loki`) and expire after
`qois.loki.retentionPeriod` (default 31 days).
