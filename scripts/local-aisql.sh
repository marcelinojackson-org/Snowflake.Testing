#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
AISQL_REPO_DIR="${AISQL_REPO_DIR:-"$REPO_ROOT/../Snowflake.AISQLAction"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR' (override with COMMON_REPO_DIR)."
[[ -d "$AISQL_REPO_DIR" ]] || die "Cannot find Snowflake.AISQLAction at '$AISQL_REPO_DIR' (override with AISQL_REPO_DIR)."

REQUIRED_VARS=(
  SNOWFLAKE_USER
  SNOWFLAKE_ROLE
  SNOWFLAKE_WAREHOUSE
  SNOWFLAKE_DATABASE
  SNOWFLAKE_SCHEMA
)

MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING+=("$var")
  fi
done

if [[ -z "${SNOWFLAKE_ACCOUNT:-}" && -z "${SNOWFLAKE_ACCOUNT_URL:-}" ]]; then
  MISSING+=("SNOWFLAKE_ACCOUNT or SNOWFLAKE_ACCOUNT_URL")
fi

if [[ -z "${SNOWFLAKE_PASSWORD:-}" && -z "${SNOWFLAKE_PRIVATE_KEY_PATH:-}" ]]; then
  MISSING+=("SNOWFLAKE_PASSWORD or SNOWFLAKE_PRIVATE_KEY_PATH")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  die "Missing required environment variables: ${MISSING[*]}"
fi

log "Step 1/3: install + build Snowflake.Common"
pushd "$COMMON_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm run build
npm link
popd >/dev/null

log "Step 2/3: install + build Snowflake.AISQLAction"
pushd "$AISQL_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm link @marcelinojackson-org/snowflake-common
npm run build
popd >/dev/null

PARSE_FILE="${AI_PARSE_DOCUMENT_FILE:-${AISQL_PARSE_DOCUMENT_FILE:-}}"
if [[ -z "$PARSE_FILE" ]]; then
  PARSE_FILE="TO_FILE('@docs/report.pdf')"
  log "AI_PARSE_DOCUMENT file not set; using default: $PARSE_FILE"
fi

AI_COMPLETE_ARGS=$(cat <<'JSON'
{"model":"snowflake-arctic","prompt":"Write a one-sentence summary of this repo."}
JSON
)

AI_EXTRACT_ARGS=$(cat <<'JSON'
{"text":"Order 18422 shipped to Denver on 2024-02-01 for $412.50.","response_format":{"order_id":"What is the order id?","city":"What is the destination city?","date":"What is the ship date?","amount":"What is the amount?"}}
JSON
)

AI_SENTIMENT_ARGS=$(cat <<'JSON'
{"text":"The release is promising, but the setup is a little rough."}
JSON
)

AI_CLASSIFY_ARGS=$(cat <<'JSON'
{"input":"Customer asked for a refund and billing help.","categories":["billing","support"]}
JSON
)

AI_COUNT_TOKENS_ARGS=$(cat <<'JSON'
{"function_name":"ai_complete","input_text":"Count tokens for this short sentence."}
JSON
)

AI_EMBED_ARGS=$(cat <<'JSON'
{"model":"snowflake-arctic-embed-l-v2.0","input":"Embed this sentence for semantic search."}
JSON
)

AI_SIMILARITY_ARGS=$(cat <<'JSON'
{"input1":"I love the new UI.","input2":"The interface looks great."}
JSON
)

AI_SUMMARIZE_ARGS=$(cat <<'JSON'
{"text":"This test script validates the AISQL action across basic functions with minimal inputs."}
JSON
)

AI_TRANSLATE_ARGS=$(cat <<'JSON'
{"text":"Hello world","source_language":"en","target_language":"es"}
JSON
)

AI_PARSE_DOCUMENT_ARGS=$(printf '{"file":"%s"}' "$PARSE_FILE")

failures=0
run_case() {
  local name="$1"
  local args="$2"
  log "AISQL: $name"
  if ! AI_FUNCTION="$name" AI_ARGS="$args" node dist/snowflake-aisql.js; then
    echo "AISQL test failed for $name" >&2
    failures=$((failures + 1))
  fi
}

log "Step 3/3: execute AISQL functions (basic inputs)"
pushd "$AISQL_REPO_DIR" >/dev/null
run_case "AI_COMPLETE" "$AI_COMPLETE_ARGS"
run_case "AI_EXTRACT" "$AI_EXTRACT_ARGS"
run_case "AI_SENTIMENT" "$AI_SENTIMENT_ARGS"
run_case "AI_CLASSIFY" "$AI_CLASSIFY_ARGS"
run_case "AI_COUNT_TOKENS" "$AI_COUNT_TOKENS_ARGS"
run_case "AI_EMBED" "$AI_EMBED_ARGS"
run_case "AI_SIMILARITY" "$AI_SIMILARITY_ARGS"
run_case "AI_SUMMARIZE" "$AI_SUMMARIZE_ARGS"
run_case "AI_TRANSLATE" "$AI_TRANSLATE_ARGS"
run_case "AI_PARSE_DOCUMENT" "$AI_PARSE_DOCUMENT_ARGS"
popd >/dev/null

if [[ $failures -gt 0 ]]; then
  die "$failures AISQL test(s) failed."
fi

log "AISQL tests completed successfully."
