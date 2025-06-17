#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_REPO_DIR="${COMMON_REPO_DIR:-"$REPO_ROOT/../Snowflake.Common"}"
RUNSQL_REPO_DIR="${RUNSQL_REPO_DIR:-"$REPO_ROOT/../Snowflake.RunSQLAction"}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

[[ -d "$COMMON_REPO_DIR" ]] || die "Cannot find Snowflake.Common at '$COMMON_REPO_DIR'. Override via COMMON_REPO_DIR=/path/to/repo."
[[ -d "$RUNSQL_REPO_DIR" ]] || die "Cannot find Snowflake.RunSQLAction at '$RUNSQL_REPO_DIR'. Override via RUNSQL_REPO_DIR=/path/to/repo."

log "Installing + building Snowflake.Common"
pushd "$COMMON_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm run build
npm link
popd >/dev/null

log "Building Snowflake.RunSQLAction with the freshly linked common lib"
pushd "$RUNSQL_REPO_DIR" >/dev/null
npm install --no-audit --no-fund
npm link @marcelinojackson-org/snowflake-common
npm run build
VERSION="$(node -p "require('./package.json').version")"
popd >/dev/null

log "Bundle ready at $RUNSQL_REPO_DIR/dist"
cat <<EOF
Next steps:
  1. Review git status in Snowflake.RunSQLAction and commit any changes.
  2. Tag the release: (cd "$RUNSQL_REPO_DIR" && git tag -f v$VERSION && git push origin v$VERSION)
  3. Draft the Marketplace release using tag v$VERSION.
EOF
