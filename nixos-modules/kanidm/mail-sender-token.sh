token_file=$3

account=$(jq -r .account "$settings")
display_name=$(jq -r .displayName "$settings")
token_label=$(jq -r .tokenLabel "$settings")
sender_group=$(jq -r .senderGroup "$settings")
manager=$(jq -r .manager "$settings")

account_api() {
  local method=$1 path=$2
  shift 2
  api "$method" "service_account/$account$path" "$@"
}

ensure_service_account() {
  if [[ $(account_api GET "") == null ]]; then
    echo "kanidm mail sender: creating service account $account"
    jq --null-input --arg name "$account" --arg displayname "$display_name" --arg manager "$manager" \
      '{attrs: {name: [$name], displayname: [$displayname], entry_managed_by: [$manager]}}' |
      api POST service_account --json @- >/dev/null
  fi
}

revoke_labelled_tokens() {
  local token_ids token_id
  token_ids=$(account_api GET /_api_token | jq -r --arg label "$token_label" '.[] | select(.label == $label) | .token_id')
  for token_id in $token_ids; do
    echo "kanidm mail sender: revoking token $token_id"
    account_api DELETE "/_api_token/$token_id" >/dev/null
  done
}

token_rejected() {
  local status
  status=$(
    curl --silent --show-error "${curl_tls[@]}" \
      --header @<(headers "Authorization: Bearer $(<"$token_file")") \
      --output /dev/null --write-out '%{http_code}' "$url/v1/auth/valid"
  ) || true
  case $status in
  200) return 1 ;;
  401)
    echo "kanidm mail sender: stored token rejected"
    return 0
    ;;
  *)
    echo "kanidm mail sender: validating stored token failed with status $status" >&2
    exit 1
    ;;
  esac
}

generate_token() {
  echo "kanidm mail sender: generating token for $account"
  revoke_labelled_tokens
  pending_token=$(mktemp "$token_file.XXXXXX")
  trap 'rm -f "$pending_token"' EXIT
  jq --null-input --arg label "$token_label" '{label: $label, expiry: null, read_write: true}' |
    account_api POST /_api_token --json @- |
    jq --exit-status --raw-output strings >"$pending_token"
  mv "$pending_token" "$token_file"
}

ensure_sender_membership() {
  if ! api GET "group/$sender_group/_attr/member" | jq -e --arg account "$account@" 'any(.[]?; startswith($account))' >/dev/null; then
    echo "kanidm mail sender: adding $account to $sender_group"
    api POST "group/$sender_group/_attr/member" --json "$(jq --null-input --arg account "$account" '[$account]')" >/dev/null
  fi
}

rm -f "$token_file".??????
authenticate
ensure_service_account
if [[ ! -s $token_file ]] || token_rejected; then
  generate_token
fi
ensure_sender_membership
