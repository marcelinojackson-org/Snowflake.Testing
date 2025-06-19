#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
CORTEX_REPO_DIR="${CORTEX_REPO_DIR:-"$REPO_ROOT/../Snowflake.CortexAI.SearchAction"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR' (override with COMMON_REPO_DIR)."
[[ -d "$CORTEX_REPO_DIR" ]] || die "Cannot find Snowflake.CortexAI.SearchAction at '$CORTEX_REPO_DIR' (override with CORTEX_REPO_DIR)."

REQUIRED_VARS=(
  SNOWFLAKE_ACCOUNT_URL
  SNOWFLAKE_PAT
  SEARCH_SERVICE
  SEARCH_QUERY
)

MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING+=("$var")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  die "Missing required environment variables: ${MISSING[*]}"
fi

log "Step 1/3: install + build Snowflake.Common"
pushd "$COMMON_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm run build
npm link
popd >/dev/null

log "Step 2/3: install + build Snowflake.CortexAI.SearchAction"
pushd "$CORTEX_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm link @marcelinojackson-org/snowflake-common
npm run build
popd >/dev/null

log "Step 3/3: execute basic Cortex Search (bundle layer)"
pushd "$CORTEX_REPO_DIR" >/dev/null
node dist/snowflake-cortex-search.js
popd >/dev/null

log "Step 4/4: execute advanced Cortex Search (bundle layer)"
pushd "$CORTEX_REPO_DIR" >/dev/null
ADV_SERVICE="${SEARCH_SERVICE_ADV:-$SEARCH_SERVICE}"
ADV_QUERY="${SEARCH_QUERY_ADV:-$SEARCH_QUERY}"
ADV_LIMIT="${SEARCH_LIMIT_ADV:-3}"
if [[ -z "${SEARCH_FILTER_ADV:-}" && -z "${SEARCH_FILTER:-}" ]]; then
  ADV_FILTER=$(cat <<'JSON'
{
  "@and": [
    { "@eq": { "NATION": "FRANCE" } },
    { "@eq": { "O_ORDERSTATUS": "F" } }
  ]
}
JSON
)
else
ADV_FILTER="${SEARCH_FILTER_ADV:-$SEARCH_FILTER}"
fi
ADV_FIELDS="${SEARCH_FIELDS_ADV:-"CUSTOMER_REVIEW"}"
ADV_OFFSET="${SEARCH_OFFSET_ADV:-0}"
ADV_INCLUDE_SCORES="${SEARCH_INCLUDE_SCORES_ADV:-false}"
ADV_SCORE_THRESHOLD="${SEARCH_SCORE_THRESHOLD_ADV:-""}"
ADV_RERANKER="${SEARCH_RERANKER_ADV:-""}"
ADV_RANKING_PROFILE="${SEARCH_RANKING_PROFILE_ADV:-""}"

SEARCH_SERVICE="$ADV_SERVICE" \
SEARCH_QUERY="$ADV_QUERY" \
SEARCH_LIMIT="$ADV_LIMIT" \
SEARCH_FILTER="$ADV_FILTER" \
SEARCH_FIELDS="$ADV_FIELDS" \
SEARCH_OFFSET="$ADV_OFFSET" \
SEARCH_INCLUDE_SCORES="$ADV_INCLUDE_SCORES" \
SEARCH_SCORE_THRESHOLD="$ADV_SCORE_THRESHOLD" \
SEARCH_RERANKER="$ADV_RERANKER" \
SEARCH_RANKING_PROFILE="$ADV_RANKING_PROFILE" \
node dist/snowflake-cortex-search.js
popd >/dev/null

log "Local Cortex Search test completed successfully."
