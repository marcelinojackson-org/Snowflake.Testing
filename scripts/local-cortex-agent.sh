#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
AGENT_REPO_DIR="${AGENT_REPO_DIR:-"$REPO_ROOT/../Snowflake.CortexAI.AgentAction"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR' (override with COMMON_REPO_DIR)."
[[ -d "$AGENT_REPO_DIR" ]] || die "Cannot find Snowflake.CortexAI.AgentAction at '$AGENT_REPO_DIR' (override with AGENT_REPO_DIR)."

REQUIRED_VARS=(
  SNOWFLAKE_ACCOUNT_URL
  SNOWFLAKE_PAT
  AGENT_DATABASE
  AGENT_SCHEMA
  AGENT_NAME
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

log "Step 1/4: install + build Snowflake.Common"
pushd "$COMMON_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm run build
npm link
popd >/dev/null

log "Step 2/4: install + build Snowflake.CortexAI.AgentAction"
pushd "$AGENT_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm link @marcelinojackson-org/snowflake-common
npm run build
popd >/dev/null

log "Step 3/4: execute basic Cortex Agent scenario"
pushd "$AGENT_REPO_DIR" >/dev/null
AGENT_MESSAGE_VALUE="${AGENT_MESSAGE:-"ROLE:MANAGER Summarize employees who joined in the last 180 days."}"
AGENT_DATABASE="$AGENT_DATABASE" \
AGENT_SCHEMA="$AGENT_SCHEMA" \
AGENT_NAME="$AGENT_NAME" \
AGENT_MESSAGE="$AGENT_MESSAGE_VALUE" \
AGENT_PERSIST_RESULTS="${AGENT_PERSIST_RESULTS:-true}" \
node dist/snowflake-cortex-agent.js
popd >/dev/null

log "Step 4/4: execute advanced Cortex Agent scenario"
pushd "$AGENT_REPO_DIR" >/dev/null
ADV_MESSAGES='[
  {
    "role":"user",
    "content":[
      {
        "type":"text",
        "text":"ROLE:MANAGER Summarize employees who joined in the last 180 days and provide only high-level aggregates plus the top 5 example employees. Highlight just the top regions."
      }
    ]
  }
]'
ADV_THREAD_ID="${AGENT_THREAD_ID:-}"
ADV_PARENT_ID="${AGENT_PARENT_MESSAGE_ID:-}"
env_cmd=(env AGENT_MESSAGES="$ADV_MESSAGES")
if [[ -n "$ADV_THREAD_ID" ]]; then
  env_cmd+=("AGENT_THREAD_ID=$ADV_THREAD_ID")
fi
if [[ -n "$ADV_PARENT_ID" ]]; then
  env_cmd+=("AGENT_PARENT_MESSAGE_ID=$ADV_PARENT_ID")
fi
env_cmd+=(
  AGENT_TOOL_CHOICE='{"type":"auto","name":["Employee_Details_With_Salary-Analyst","EMPLOYEE_DOCS-SEARCH"]}'
  AGENT_DATABASE="$AGENT_DATABASE"
  AGENT_SCHEMA="$AGENT_SCHEMA"
  AGENT_NAME="$AGENT_NAME"
  AGENT_PERSIST_RESULTS="${AGENT_PERSIST_RESULTS:-true}"
  node dist/snowflake-cortex-agent.js
)

"${env_cmd[@]}"
popd >/dev/null

log "Local Cortex Agent test completed successfully."
