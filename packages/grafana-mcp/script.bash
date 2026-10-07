#!/usr/bin/env bash

#### Environment
export GRAFANA_URL="https://monitoring.qo.is"
KEYRING_ATTRIBUTES=(service mcp-grafana url "${GRAFANA_URL}")

#### Execution
if [ "${1:-}" = "login" ]; then
  echo "🔑 Create a service account token at ${GRAFANA_URL}/org/serviceaccounts"
  read -rsp "Token: " TOKEN
  echo
  curl -fsS -o /dev/null -H "Authorization: Bearer ${TOKEN}" "${GRAFANA_URL}/api/search?limit=1"
  printf '%s' "${TOKEN}" | secret-tool store --label="Grafana MCP (${GRAFANA_URL})" "${KEYRING_ATTRIBUTES[@]}"
  echo "✅ Token stored in keyring."
  exit 0
fi

if ! GRAFANA_SERVICE_ACCOUNT_TOKEN="$(secret-tool lookup "${KEYRING_ATTRIBUTES[@]}")"; then
  echo '🛑 Error: No Grafana token in keyring, run "grafana-mcp login" first.' 1>&2
  exit 1
fi
export GRAFANA_SERVICE_ACCOUNT_TOKEN

exec mcp-grafana "$@"
