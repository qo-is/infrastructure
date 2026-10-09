nothing_to_do=2
status=0
updates=$(
  fwupdmgr get-updates --json \
    --no-unreported-check --no-metadata-check --no-remote-check --no-authenticate
) || status=$?

if [ "$status" -ne 0 ] && [ "$status" -ne "$nothing_to_do" ]; then
  exit "$status"
fi

jq --slurp --raw-output '
  [.[0].Devices[]? | select((.Releases // []) | length > 0)]
  | "fwupd_updates devices=\(length)i"
' <<<"$updates"
