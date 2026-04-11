# Telegraf

Runs [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) as a metrics agent, collecting basic host metrics and exposing them in Prometheus format on port `9273`.

## References

Config inspired by:

- https://github.com/nix-community/srvos/blob/main/shared/mixins/telegraf.nix
- https://github.com/nix-community/srvos/blob/main/nixos/mixins/telegraf.nix
