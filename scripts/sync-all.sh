#!/usr/bin/env bash
# Reads config/repos.json and runs sync-target.sh for each enabled source.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/repos.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing $CONFIG (copy config/repos.example.json)." >&2
  exit 1
fi

PORTFOLIO_PID="$(jq -r '.portfolio.project_id' "$CONFIG")"
FIELD_ID="$(jq -r '.portfolio.next_action_field_id' "$CONFIG")"

failures=0
while IFS= read -r row; do
  SOURCE_ID="$(echo "$row" | jq -r '.id')"
  ENABLED="$(echo "$row" | jq -r '.enabled // true')"
  [[ "$ENABLED" == "false" ]] && continue

  export SOURCE_ID
  export PORTFOLIO_PROJECT_ID="$PORTFOLIO_PID"
  export NEXT_ACTION_FIELD_ID="$FIELD_ID"
  export PORTFOLIO_ITEM_ID="$(echo "$row" | jq -r '.portfolio_item_id')"
  export PROJECT_OWNER="$(echo "$row" | jq -r '.roadmap.owner_login')"
  export ROADMAP_PROJECT_NUMBER="$(echo "$row" | jq -r '.roadmap.project_number')"
  ROADMAP_OWNER="$(echo "$row" | jq -r '.roadmap.owner_login')"
  ROADMAP_NUM="$(echo "$row" | jq -r '.roadmap.project_number')"
  export ROADMAP_URL="https://github.com/users/${ROADMAP_OWNER}/projects/${ROADMAP_NUM}"

  set +e
  "${ROOT}/scripts/sync-target.sh"
  ec=$?
  set -e
  if [[ "$ec" -ne 0 ]]; then
    echo "::error::Sync failed for source ${SOURCE_ID}" >&2
    failures=$((failures + 1))
  fi
  echo ""
done < <(jq -c '.sources[]' "$CONFIG")

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "All sources synced."
