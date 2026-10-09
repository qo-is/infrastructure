# Prometheus

This module enables the main Prometheus server which scrapes and stores time series data.

## Web UI

Prometheus: https://prometheus.qo.is, Alertmanager: https://prometheus.qo.is/alertmanager/ (kanidm `sysadmin` login).

oauth2-proxy cookie secret:

```bash
sops set private/nixos-configurations/lindberg-webapps/secrets.sops.yaml \
  '["oauth2-proxy"]["cookie-secret"]' "\"$(openssl rand -hex 16)\""
```

## Storage

Data is stored the default prometheus location with the default retention. **Data is not backed up.**

## References

Prometheus has [an excellent documentation page](https://prometheus.io/docs/concepts/data_model/) that describes the fundamental concept and configuration options.
