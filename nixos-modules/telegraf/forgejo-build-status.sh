base_url=$1
owner=$2
repo=$3
branch=$4

curl --silent --show-error --fail --max-time 10 \
  "$base_url/api/v1/repos/$owner/$repo/commits/$branch/status" |
  jq --raw-output --arg owner "$owner" --arg repo "$repo" --arg branch "$branch" '
    ({success: 0, pending: 1, warning: 2, failure: 3, error: 3}[.state] // 4) as $value
    | [.statuses[]?.updated_at | fromdateiso8601] as $updates
    | "forgejo_build_status,owner=\($owner),repo=\($repo),branch=\($branch) value=\($value)i"
      + (if .state == "success" and ($updates | length) > 0
         then ",last_success_timestamp=\($updates | max)i"
         else "" end)
  '
