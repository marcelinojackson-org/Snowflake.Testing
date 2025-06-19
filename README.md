## Snowflake Testing Utilities

This repo hosts CI workflows plus helper scripts that make it easy to validate cross-repo changes before pushing.

### scripts/validate-common.sh

- Builds and tests `../Snowflake.Common`.
- Uses your local `SNOWFLAKE_*` env vars (if set) to run a live smoke test via the compiled library.
- Usage:

  ```bash
  ./scripts/validate-common.sh
  # or override locations / SQL
  COMMON_REPO_DIR=/path/to/Snowflake.Common \
  VALIDATION_SQL='select current_warehouse() as current_warehouse' \
  ./scripts/validate-common.sh
  ```

### scripts/build-runsql-release.sh

- Rebuilds `Snowflake.Common`, links it, and bundles `../Snowflake.RunSQLAction` so the action is ready for tagging/publishing.
- Usage:

  ```bash
  ./scripts/build-runsql-release.sh
  # override repo locations if needed
  COMMON_REPO_DIR=~/dev/Snowflake.Common \
  RUNSQL_REPO_DIR=~/dev/Snowflake.RunSQLAction \
  ./scripts/build-runsql-release.sh
  ```

Both scripts assume this repo sits alongside `Snowflake.Common` and `Snowflake.RunSQLAction` (matching the current layout under `/Users/marc/dev/opensource/Snowflake`). Adjust the env vars if your workspace differs.

### scripts/local-integration-test.sh

- Full end-to-end local validation: builds/links the common lib, runs a smoke query through it, rebuilds the RunSQL action, and executes the bundled action (`node dist/snowflake-runsql.js`) using your existing `SNOWFLAKE_*` env vars.
- Usage:

  ```bash
  ./scripts/local-integration-test.sh
  # customize SQL statements if needed
  SMOKE_SQL='select current_database()' \
  ACTION_SQL='show tables limit 5' \
  ./scripts/local-integration-test.sh
  ```

### scripts/local-cortex-search.sh

- Builds `../Snowflake.Common` and `../Snowflake.CortexAI.SearchAction`, then runs the bundled Cortex Search action (`node dist/snowflake-cortex-search.js`) using your `SNOWFLAKE_ACCOUNT_URL`, `SNOWFLAKE_PAT`, `SEARCH_SERVICE`, and `SEARCH_QUERY` env vars.
- Usage:

  ```bash
  ./scripts/local-cortex-search.sh
  CORTEX_REPO_DIR=~/dev/Snowflake.CortexAI.SearchAction \
  SEARCH_SERVICE='SNOWFLAKE_SAMPLE_CORTEXAI_DB.SEARCH_DATA.CUSTOMER_REVIEW_SEARCH' \
  SEARCH_QUERY='Find orders with complaints about delivery' \
  ./scripts/local-cortex-search.sh
  ```
