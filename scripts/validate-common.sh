#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
VALIDATION_SQL="${VALIDATION_SQL:-"select current_schema() as current_schema"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR' (override with COMMON_REPO_DIR=/path/to/repo)."

log "Using Snowflake.Common at $COMMON_REPO_DIR"

pushd "$COMMON_REPO_DIR" >/dev/null

log "Installing dependencies"
npm install --no-audit --no-fund

log "Building TypeScript outputs"
npm run build

if npm run | grep -q "^  test"; then
  log "Running unit tests"
  npm test
else
  log "No npm test script defined - skipping Jest step"
fi

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
  log "Skipping live Snowflake smoke test (missing: ${MISSING_VARS[*]})."
  popd >/dev/null
  exit 0
fi

log "Executing live Snowflake smoke test via dist/connection.js"
COMMON_REPO_DIR="$COMMON_REPO_DIR" node <<'NODE'
const path = require('path');
const modulePath = path.join(process.env.COMMON_REPO_DIR, 'dist', 'connection.js');
const { getSnowflakeConnection, runSql } = require(modulePath);

(async () => {
  try {
    const conn = await getSnowflakeConnection();
    console.log('Connection summary:', JSON.stringify(conn, null, 2));

    const sql = process.env.VALIDATION_SQL || 'select current_schema() as current_schema';
    const query = await runSql(sql);
    console.log(`SQL "${sql}" result:`, JSON.stringify(query, null, 2));
  } catch (err) {
    console.error('Snowflake smoke test failed:', err);
    process.exitCode = 1;
  }
})();
NODE

popd >/dev/null
