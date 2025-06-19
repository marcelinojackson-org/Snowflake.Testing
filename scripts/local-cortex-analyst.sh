#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
ANALYST_REPO_DIR="${ANALYST_REPO_DIR:-"$REPO_ROOT/../Snowflake.CortexAI.AnalystAction"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR' (override with COMMON_REPO_DIR)."
[[ -d "$ANALYST_REPO_DIR" ]] || die "Cannot find Snowflake.CortexAI.AnalystAction at '$ANALYST_REPO_DIR' (override with ANALYST_REPO_DIR)."

REQUIRED_VARS=(
  SNOWFLAKE_ACCOUNT_URL
  SNOWFLAKE_PAT
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

SEMANTIC_MODEL_PATH_VALUE="${SEMANTIC_MODEL_PATH:-@\"SNOWFLAKE_SAMPLE_CORTEXAI_DB\".\"HRANALYTICS\".\"SEMANTIC_MODELS_STAGE\"/EMPLOYEE_DETAILS_WITHOUT_SALARY_SV.yaml}"
SEMANTIC_VIEW_PATH_VALUE="${SEMANTIC_VIEW_PATH:-}"

if [[ -z "$SEMANTIC_MODEL_PATH_VALUE" ]]; then
  die "Set SEMANTIC_MODEL_PATH for the basic Cortex Analyst scenario."
fi

if [[ -z "$SEMANTIC_VIEW_PATH_VALUE" ]]; then
  die "Set SEMANTIC_VIEW_PATH for the advanced Cortex Analyst scenario."
fi

log "Step 1/4: install + build Snowflake.Common"
pushd "$COMMON_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm run build
npm link
popd >/dev/null

log "Step 2/4: install + build Snowflake.CortexAI.AnalystAction"
pushd "$ANALYST_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm link @marcelinojackson-org/snowflake-common
npm run build
popd >/dev/null

log "Step 3/4: execute basic Cortex Analyst scenario (semantic model)"
pushd "$ANALYST_REPO_DIR" >/dev/null
ANALYST_MESSAGE_VALUE="${ANALYST_MESSAGE:-"How many employees were hired in 2021 and what is their current employment status?"}"
ANALYST_INCLUDE_SQL_VALUE="${ANALYST_INCLUDE_SQL:-false}"
ANALYST_RESULT_FORMAT_VALUE="${ANALYST_RESULT_FORMAT:-markdown}"
ANALYST_TEMPERATURE_VALUE="${ANALYST_TEMPERATURE:-}"
ANALYST_MAX_OUTPUT_TOKENS_VALUE="${ANALYST_MAX_OUTPUT_TOKENS:-}"

SEMANTIC_MODEL_PATH="$SEMANTIC_MODEL_PATH_VALUE" \
SEMANTIC_VIEW_PATH="" \
ANALYST_MESSAGE="$ANALYST_MESSAGE_VALUE" \
ANALYST_INCLUDE_SQL="$ANALYST_INCLUDE_SQL_VALUE" \
ANALYST_RESULT_FORMAT="$ANALYST_RESULT_FORMAT_VALUE" \
ANALYST_TEMPERATURE="$ANALYST_TEMPERATURE_VALUE" \
ANALYST_MAX_OUTPUT_TOKENS="$ANALYST_MAX_OUTPUT_TOKENS_VALUE" \
node dist/snowflake-cortex-analyst.js
popd >/dev/null

log "Step 4/4: execute advanced Cortex Analyst scenario (semantic view + options)"
pushd "$ANALYST_REPO_DIR" >/dev/null
ADV_ANALYST_MESSAGE="${ANALYST_ADVANCED_MESSAGE:-"Explain the dataset."}"
ADV_INCLUDE_SQL="${ANALYST_ADVANCED_INCLUDE_SQL:-true}"
ADV_RESULT_FORMAT="${ANALYST_ADVANCED_RESULT_FORMAT:-json}"
ADV_TEMPERATURE="${ANALYST_ADVANCED_TEMPERATURE:-0.15}"
ADV_MAX_OUTPUT_TOKENS="${ANALYST_ADVANCED_MAX_OUTPUT_TOKENS:-600}"

SEMANTIC_MODEL_PATH="" \
SEMANTIC_VIEW_PATH="$SEMANTIC_VIEW_PATH_VALUE" \
ANALYST_MESSAGE="$ADV_ANALYST_MESSAGE" \
ANALYST_INCLUDE_SQL="$ADV_INCLUDE_SQL" \
ANALYST_RESULT_FORMAT="$ADV_RESULT_FORMAT" \
ANALYST_TEMPERATURE="$ADV_TEMPERATURE" \
ANALYST_MAX_OUTPUT_TOKENS="$ADV_MAX_OUTPUT_TOKENS" \
node dist/snowflake-cortex-analyst.js
popd >/dev/null

log "Local Cortex Analyst test completed successfully."
