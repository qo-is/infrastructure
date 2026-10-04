group_api() {
  local method=$1 path=$2
  shift 2
  api "$method" "group/$path" "$@"
}

first_value() {
  group_api GET "$1/_attr/$2" | jq --raw-output '.[0] // empty'
}

set_parent_membership() {
  local method=$1 group=$2 parents=$3 parent
  for parent in $parents; do
    group_api "$method" "$parent/_attr/member" --json "$(jq --null-input --arg group "$group" '[$group]')" >/dev/null
  done
}

# A high privilege group can only be changed by its entry managers, so the group is
# detached from its parents while its entry manager is set.
set_entry_manager() {
  local group=$1 manager=$2 parents=$3
  echo "kanidm entry managers: managing $group by $manager"
  set_parent_membership DELETE "$group" "$parents"
  group_api PUT "$group/_attr/entry_managed_by" --json "$(jq --null-input --arg manager "$manager" '[$manager]')" >/dev/null
  set_parent_membership POST "$group" "$parents"
}

ensure_entry_manager() {
  local group=$1 manager=$2 parents=$3 current expected
  current=$(first_value "$group" entry_managed_by)
  expected=$(first_value "$manager" spn)
  if [[ $current != "$expected" ]]; then
    set_entry_manager "$group" "$manager" "$parents"
  fi
}

authenticate

jq -r '.groups | to_entries[] | [.key, .value.manager, (.value.parents | join(" "))] | @tsv' "$settings" |
  while IFS=$'\t' read -r group manager parents; do
    ensure_entry_manager "$group" "$manager" "$parents"
  done
