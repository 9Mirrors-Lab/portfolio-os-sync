#!/usr/bin/env bash
# One roadmap → one Portfolio OS Next Action update.
# Required env: PROJECT_OWNER, ROADMAP_PROJECT_NUMBER, ROADMAP_URL (optional),
#   PORTFOLIO_PROJECT_ID, PORTFOLIO_ITEM_ID, NEXT_ACTION_FIELD_ID

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required." >&2
  exit 1
fi

PROJECT_OWNER="${PROJECT_OWNER:?}"
ROADMAP_PROJECT_NUMBER="${ROADMAP_PROJECT_NUMBER:?}"
PORTFOLIO_PROJECT_ID="${PORTFOLIO_PROJECT_ID:?}"
PORTFOLIO_ITEM_ID="${PORTFOLIO_ITEM_ID:?}"
NEXT_ACTION_FIELD_ID="${NEXT_ACTION_FIELD_ID:?}"
ROADMAP_URL="${ROADMAP_URL:-https://github.com/users/${PROJECT_OWNER}/projects/${ROADMAP_PROJECT_NUMBER}}"

QUERY='
query($login: String!, $n: Int!) {
  user(login: $login) {
    projectV2(number: $n) {
      items(first: 100) {
        nodes {
          fieldValues(first: 25) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldTextValue {
                text
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2FieldCommon { name } }
              }
            }
          }
        }
      }
    }
  }
}'

RESP="$(gh api graphql -f query="$QUERY" -f login="$PROJECT_OWNER" -F n="$ROADMAP_PROJECT_NUMBER")"

TITLES_STATUSES="$(echo "$RESP" | jq -r '
  .data.user.projectV2.items.nodes[]
  | .fieldValues.nodes as $n
  | (
      ($n | map(select(.field != null and .field.name == "Title") | .text) | first // "")
    ) as $title
  | (
      ($n | map(select(.field != null and .field.name == "Status") | .name) | first // "")
    ) as $status
  | select($title != "" and ($status == "Next Up" or $status == "In Progress"))
  | "\($status)\t\($title)"
')"

NEXT_UP_LIST=()
IN_PROGRESS_LIST=()
MAX_PER_BUCKET=8

while IFS=$'\t' read -r status title; do
  [[ -z "${status:-}" ]] && continue
  case "$status" in
    "Next Up")
      if ((${#NEXT_UP_LIST[@]} < MAX_PER_BUCKET)); then
        NEXT_UP_LIST+=("$title")
      fi
      ;;
    "In Progress")
      if ((${#IN_PROGRESS_LIST[@]} < MAX_PER_BUCKET)); then
        IN_PROGRESS_LIST+=("$title")
      fi
      ;;
  esac
done <<< "$TITLES_STATUSES"

join_by_comma() {
  local out="" s
  local first=1
  for s in "$@"; do
    if [[ -n "$s" ]]; then
      if [[ "$first" -eq 1 ]]; then
        out="$s"
        first=0
      else
        out+=", ${s}"
      fi
    fi
  done
  echo "$out"
}

LINE_NEXT="$(join_by_comma "${NEXT_UP_LIST[@]:-}")"
LINE_IP="$(join_by_comma "${IN_PROGRESS_LIST[@]:-}")"

if [[ -z "$LINE_NEXT" && -z "$LINE_IP" ]]; then
  BODY="Roadmap: nothing in Next up or In progress. (${ROADMAP_URL})"
else
  BODY=""
  [[ -n "$LINE_NEXT" ]] && BODY="Next up: ${LINE_NEXT}"
  [[ -n "$LINE_IP" ]] && {
    [[ -n "$BODY" ]] && BODY+=" · "
    BODY+="In progress: ${LINE_IP}"
  }
  BODY+=" (${ROADMAP_URL})"
fi

if ((${#BODY} > 900)); then
  BODY="${BODY:0:897}…"
fi

echo "[${SOURCE_ID:-sync-target}] Next Action →"
echo "$BODY"

gh api graphql -f query='
mutation($pid: ID!, $iid: ID!, $fid: ID!, $txt: String!) {
  updateProjectV2ItemFieldValue(
    input: { projectId: $pid, itemId: $iid, fieldId: $fid, value: { text: $txt } }
  ) {
    projectV2Item { id }
  }
}' -f pid="$PORTFOLIO_PROJECT_ID" -f iid="$PORTFOLIO_ITEM_ID" -f fid="$NEXT_ACTION_FIELD_ID" -f txt="$BODY" >/dev/null

echo "[${SOURCE_ID:-sync-target}] Done."
