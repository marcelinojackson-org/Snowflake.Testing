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

PARSE_FILE_OBJECT="${AI_PARSE_DOCUMENT_FILE_OBJECT:-${AISQL_PARSE_DOCUMENT_FILE_OBJECT:-}}"
PARSE_FILE="${AI_PARSE_DOCUMENT_FILE:-${AISQL_PARSE_DOCUMENT_FILE:-${AI_PARSE_DOCUMENT:-}}}"
SKIP_PARSE_DOCUMENT=0
if [[ -z "$PARSE_FILE" && -z "$PARSE_FILE_OBJECT" ]]; then
  SKIP_PARSE_DOCUMENT=1
  log "AI_PARSE_DOCUMENT file not set; skipping parse document test (set AI_PARSE_DOCUMENT_FILE to enable)."
elif [[ -n "$PARSE_FILE" && "$PARSE_FILE" =~ ^(/|~|file://) ]]; then
  SKIP_PARSE_DOCUMENT=1
  log "AI_PARSE_DOCUMENT expects a staged file reference; skipping local path (use @stage/path or AI_PARSE_DOCUMENT_FILE_OBJECT)."
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

USE_CORTEX_NAMES="${USE_CORTEX_NAMES:-0}"
if [[ "$USE_CORTEX_NAMES" == "1" ]]; then
  FN_COMPLETE="SNOWFLAKE.CORTEX.COMPLETE"
  FN_EXTRACT="SNOWFLAKE.CORTEX.EXTRACT"
  FN_SENTIMENT="SNOWFLAKE.CORTEX.SENTIMENT"
  FN_CLASSIFY="SNOWFLAKE.CORTEX.CLASSIFY"
  FN_COUNT_TOKENS="SNOWFLAKE.CORTEX.COUNT_TOKENS"
  FN_EMBED="SNOWFLAKE.CORTEX.EMBED"
  FN_SIMILARITY="SNOWFLAKE.CORTEX.SIMILARITY"
  FN_SUMMARIZE="SNOWFLAKE.CORTEX.SUMMARIZE"
  FN_TRANSLATE="SNOWFLAKE.CORTEX.TRANSLATE"
  FN_PARSE_DOCUMENT="SNOWFLAKE.CORTEX.PARSE_DOCUMENT"
  COUNT_TOKENS_FUNCTION_NAME="SNOWFLAKE.CORTEX.SENTIMENT"
else
  FN_COMPLETE="AI_COMPLETE"
  FN_EXTRACT="AI_EXTRACT"
  FN_SENTIMENT="AI_SENTIMENT"
  FN_CLASSIFY="AI_CLASSIFY"
  FN_COUNT_TOKENS="AI_COUNT_TOKENS"
  FN_EMBED="AI_EMBED"
  FN_SIMILARITY="AI_SIMILARITY"
  FN_SUMMARIZE="SNOWFLAKE.CORTEX.SUMMARIZE"
  FN_TRANSLATE="AI_TRANSLATE"
  FN_PARSE_DOCUMENT="AI_PARSE_DOCUMENT"
  COUNT_TOKENS_FUNCTION_NAME="ai_sentiment"
fi

AI_COUNT_TOKENS_ARGS=$(printf '{"function_name":"%s","input_text":"Count tokens for this short sentence."}' "$COUNT_TOKENS_FUNCTION_NAME")

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

if [[ "$SKIP_PARSE_DOCUMENT" -eq 0 && -n "$PARSE_FILE_OBJECT" ]]; then
  AI_PARSE_DOCUMENT_ARGS=$(printf '{"file_object":"%s"}' "$PARSE_FILE_OBJECT")
elif [[ "$SKIP_PARSE_DOCUMENT" -eq 0 ]]; then
  AI_PARSE_DOCUMENT_ARGS=$(printf '{"file":"%s"}' "$PARSE_FILE")
fi

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
run_case "$FN_COMPLETE" "$AI_COMPLETE_ARGS"
run_case "$FN_EXTRACT" "$AI_EXTRACT_ARGS"
run_case "$FN_SENTIMENT" "$AI_SENTIMENT_ARGS"
run_case "$FN_CLASSIFY" "$AI_CLASSIFY_ARGS"
run_case "$FN_COUNT_TOKENS" "$AI_COUNT_TOKENS_ARGS"
run_case "$FN_EMBED" "$AI_EMBED_ARGS"
run_case "$FN_SIMILARITY" "$AI_SIMILARITY_ARGS"
run_case "$FN_SUMMARIZE" "$AI_SUMMARIZE_ARGS"
run_case "$FN_TRANSLATE" "$AI_TRANSLATE_ARGS"
if [[ "$SKIP_PARSE_DOCUMENT" -eq 0 ]]; then
  run_case "$FN_PARSE_DOCUMENT" "$AI_PARSE_DOCUMENT_ARGS"
fi

RUN_AISQL_ADVANCED="${RUN_AISQL_ADVANCED:-0}"
if [[ "$RUN_AISQL_ADVANCED" == "1" ]]; then
  log "AISQL advanced mode enabled"

  AI_COMPLETE_ADV_ARGS=$(cat <<'JSON'
{"model":"snowflake-arctic","prompt":"Summarize the top 2 goals of this repo.","model_parameters":{"temperature":0.2,"max_tokens":128},"show_details":true}
JSON
)

  if [[ -n "${AI_CLASSIFY_CONFIG_OBJECT:-}" ]]; then
    AI_CLASSIFY_ADV_ARGS=$(printf '{"input":"User asked about refunds and billing credits.","categories":[{"label":"billing","description":"Payment, invoice, refund topics"},{"label":"support","description":"Product help or troubleshooting"}],"config_object":%s}' "$AI_CLASSIFY_CONFIG_OBJECT")
  fi

  AI_COUNT_TOKENS_ADV_ARGS=$(cat <<'JSON'
{"function_name":"ai_complete","input_text":"Count tokens for this longer sentence.","model_name":"snowflake-arctic"}
JSON
)

  run_case "$FN_COMPLETE" "$AI_COMPLETE_ADV_ARGS"
  if [[ -n "${AI_CLASSIFY_ADV_ARGS:-}" ]]; then
    run_case "$FN_CLASSIFY" "$AI_CLASSIFY_ADV_ARGS"
  else
    log "Skipping AI_CLASSIFY config_object test (set AI_CLASSIFY_CONFIG_OBJECT)."
  fi
  run_case "$FN_COUNT_TOKENS" "$AI_COUNT_TOKENS_ADV_ARGS"

  if [[ -n "${AI_EXTRACT_FILE_OBJECT:-}" ]]; then
    AI_EXTRACT_FILE_ADV_ARGS=$(printf '{"file_object":"%s","response_format":{"invoice":"What is the invoice number?","total":"What is the total?"}}' "$AI_EXTRACT_FILE_OBJECT")
    run_case "$FN_EXTRACT" "$AI_EXTRACT_FILE_ADV_ARGS"
  else
    log "Skipping AI_EXTRACT file-based test (set AI_EXTRACT_FILE_OBJECT)."
  fi

  if [[ -n "${AI_EMBED_INPUT_FILE_OBJECT:-}" ]]; then
    AI_EMBED_ADV_ARGS=$(printf '{"model":"snowflake-arctic-embed-l-v2.0","input_file":"%s"}' "$AI_EMBED_INPUT_FILE_OBJECT")
    run_case "$FN_EMBED" "$AI_EMBED_ADV_ARGS"
  else
    log "Skipping AI_EMBED file-based test (set AI_EMBED_INPUT_FILE_OBJECT)."
  fi

  if [[ -n "${AI_SIMILARITY_INPUT1_FILE_OBJECT:-}" && -n "${AI_SIMILARITY_INPUT2_FILE_OBJECT:-}" ]]; then
    AI_SIMILARITY_ADV_ARGS=$(printf '{"input1_file":"%s","input2_file":"%s","config_object":{"measure":"cosine"}}' "$AI_SIMILARITY_INPUT1_FILE_OBJECT" "$AI_SIMILARITY_INPUT2_FILE_OBJECT")
    run_case "$FN_SIMILARITY" "$AI_SIMILARITY_ADV_ARGS"
  else
    log "Skipping AI_SIMILARITY file-based test (set AI_SIMILARITY_INPUT1_FILE_OBJECT and AI_SIMILARITY_INPUT2_FILE_OBJECT)."
  fi

  if [[ -n "${AI_PARSE_DOCUMENT_FILE_OBJECT:-}" ]]; then
    AI_PARSE_DOCUMENT_ADV_ARGS=$(printf '{"file_object":"%s","options":{"extract_tables":true}}' "$AI_PARSE_DOCUMENT_FILE_OBJECT")
    run_case "$FN_PARSE_DOCUMENT" "$AI_PARSE_DOCUMENT_ADV_ARGS"
  else
    log "Skipping AI_PARSE_DOCUMENT advanced options test (set AI_PARSE_DOCUMENT_FILE_OBJECT)."
  fi
fi
popd >/dev/null

if [[ $failures -gt 0 ]]; then
  die "$failures AISQL test(s) failed."
fi

log "AISQL tests completed successfully."
