domain_value() {
  api GET "domain/_attr/$1" | jq --raw-output '.[0] // empty'
}

ensure_domain_value() {
  local attribute=$1 expected=$2
  if [[ $(domain_value "$attribute") != "$expected" ]]; then
    echo "kanidm domain settings: setting $attribute"
    api PUT "domain/_attr/$attribute" --json "$(jq --null-input --arg value "$expected" '[$value]')" >/dev/null
  fi
}

authenticate

jq -r '.attributes | to_entries[] | [.key, .value] | @tsv' "$settings" |
  while IFS=$'\t' read -r attribute value; do
    ensure_domain_value "$attribute" "$value"
  done
