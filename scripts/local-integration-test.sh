#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
RUNSQL_REPO_DIR="${RUNSQL_REPO_DIR:-"$REPO_ROOT/../Snowflake.RunSQLAction"}"
SMOKE_SQL="${SMOKE_SQL:-"select current_schema() as current_schema"}"
ACTION_SQL="${ACTION_SQL:-"select * from information_schema.tables where table_schema = current_schema()"}"
ACTION_PERSIST_RESULTS="${ACTION_PERSIST_RESULTS:-true}"
ACTION_RESULT_FILENAME="${ACTION_RESULT_FILENAME:-snowflake-result.csv}"
ACTION_RESULT_DIR="${ACTION_RESULT_DIR:-"$RUNSQL_REPO_DIR/snowflake-results"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR'. Override COMMON_REPO_DIR."
[[ -d "$RUNSQL_REPO_DIR" ]] || die "Cannot find Snowflake.RunSQLAction at '$RUNSQL_REPO_DIR'. Override RUNSQL_REPO_DIR."

REQUIRED_VARS=(
  SNOWFLAKE_ACCOUNT
  SNOWFLAKE_USER
  SNOWFLAKE_ROLE
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING_VARS+=("$var")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  die "Missing required environment variables: ${MISSING_VARS[*]}"
fi

log "Step 1/4: install + build Snowflake.Common"
pushd "$COMMON_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm run build
npm link
popd >/dev/null

log "Step 2/4: smoke test Snowflake.Common APIs (library layer)"
COMMON_REPO_DIR="$COMMON_REPO_DIR" SMOKE_SQL="$SMOKE_SQL" node <<'NODE'
const path = require('path');
const modulePath = path.join(process.env.COMMON_REPO_DIR, 'dist', 'connection.js');
const { getSnowflakeConnection, runSql } = require(modulePath);

(async () => {
  try {
    const summary = await getSnowflakeConnection();
    console.log('Connection summary:', JSON.stringify(summary, null, 2));

    const sql = process.env.SMOKE_SQL || 'select current_schema() as current_schema';
    const query = await runSql(sql);
    console.log(`Smoke SQL "${sql}" result:`, JSON.stringify(query, null, 2));
  } catch (err) {
    console.error('Common smoke test failed:', err);
    process.exitCode = 1;
  }
})();
NODE

log "Step 3/4: build Snowflake.RunSQLAction with linked common lib"
pushd "$RUNSQL_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm link @marcelinojackson-org/snowflake-common
npm run build
popd >/dev/null

log "Step 4/4: simulate GitHub Action locally (bundle layer)"
pushd "$RUNSQL_REPO_DIR" >/dev/null
RUN_SQL_STATEMENT="$ACTION_SQL" \
RUN_SQL_PERSIST_RESULTS="$ACTION_PERSIST_RESULTS" \
RUN_SQL_RESULT_FILENAME="$ACTION_RESULT_FILENAME" \
RUN_SQL_RESULT_DIR="$ACTION_RESULT_DIR" \
node dist/snowflake-runsql.js
popd >/dev/null

log "Local integration test completed successfully."
