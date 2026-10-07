settings=$1
password_file=$2

url=$(jq -r .url "$settings")
curl_tls=()
if [[ $(jq -r .acceptInvalidCerts "$settings") == true ]]; then
  curl_tls=(--insecure)
fi

headers() {
  printf '%s\n' "$@"
}

request() {
  curl --silent --show-error --fail-with-body "${curl_tls[@]}" "$@"
}

authenticate() {
  local session_id
  session_id=$(
    request --dump-header - --output /dev/null \
      --json '{"step":{"init":"idm_admin"}}' "$url/v1/auth" |
      sed -n 's/^x-kanidm-auth-session-id: *\([^[:space:]]*\).*/\1/Ip'
  )
  session_header="X-KANIDM-AUTH-SESSION-ID: $session_id"

  request --header @<(headers "$session_header") \
    --json '{"step":{"begin":"password"}}' "$url/v1/auth" >/dev/null

  token=$(
    jq --null-input --rawfile password "$password_file" \
      '{step: {cred: {password: ($password | rtrimstr("\n"))}}}' |
      request --header @<(headers "$session_header") --json @- "$url/v1/auth" |
      jq --raw-output .state.success
  )
}

api() {
  local method=$1 path=$2
  shift 2
  request --request "$method" \
    --header @<(headers "$session_header" "Authorization: Bearer $token") \
    "$@" "$url/v1/$path"
}
