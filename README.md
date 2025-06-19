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

### scripts/local-cortex-analyst.sh

- Builds `../Snowflake.Common` and `../Snowflake.CortexAI.AnalystAction`, then executes two scenarios with the bundled action:
  1. **Semantic model run** – uses `SEMANTIC_MODEL_PATH` (defaults to `@"SNOWFLAKE_SAMPLE_CORTEXAI_DB"."HRANALYTICS"."SEMANTIC_MODELS_STAGE"/EMPLOYEE_DETAILS_WITHOUT_SALARY_SV.yaml`) and the question _“Explain the dataset.”_
  2. **Semantic view run** – requires `SEMANTIC_VIEW_PATH` (no default) and enables advanced inputs (`ANALYST_ADVANCED_*`).
- Required env: `SNOWFLAKE_ACCOUNT_URL`, `SNOWFLAKE_PAT`, `SEMANTIC_MODEL_PATH`, `SEMANTIC_VIEW_PATH`.
- Optional overrides:
  - `ANALYST_MESSAGE`, `ANALYST_INCLUDE_SQL`, `ANALYST_RESULT_FORMAT`, `ANALYST_TEMPERATURE`, `ANALYST_MAX_OUTPUT_TOKENS`
  - `ANALYST_ADVANCED_MESSAGE`, `ANALYST_ADVANCED_INCLUDE_SQL`, `ANALYST_ADVANCED_RESULT_FORMAT`, `ANALYST_ADVANCED_TEMPERATURE`, `ANALYST_ADVANCED_MAX_OUTPUT_TOKENS`
- Usage:

  ```bash
  export SEMANTIC_VIEW_PATH='SNOWFLAKE_SAMPLE_CORTEXAI_DB.HRANALYTICS.EMPLOYEE_DETAILS_WITHOUT_SALARY_SV'
  ./scripts/local-cortex-analyst.sh

  ANALYST_REPO_DIR=~/dev/Snowflake.CortexAI.AnalystAction \
  SEMANTIC_MODEL_PATH='@"SNOWFLAKE_SAMPLE_CORTEXAI_DB"."HRANALYTICS"."SEMANTIC_MODELS_STAGE"/EMPLOYEE_DETAILS_WITHOUT_SALARY_SV.yaml' \
  SEMANTIC_VIEW_PATH='SNOWFLAKE_SAMPLE_CORTEXAI_DB.HRANALYTICS.EMPLOYEE_DETAILS_WITHOUT_SALARY_SV' \
  ANALYST_MESSAGE='Explain the dataset.' \
  ./scripts/local-cortex-analyst.sh
  ```

### scripts/local-cortex-agent.sh

- Builds `../Snowflake.Common` and `../Snowflake.CortexAI.AgentAction`, then runs two conversations against your agent:
  1. **Basic** – single prompt routed to the provided agent coordinates.
  2. **Advanced** – multi-message JSON payload, explicit thread ids, and a custom `tool-choice`.
- Required env: `SNOWFLAKE_ACCOUNT_URL`, `SNOWFLAKE_PAT`, `AGENT_DATABASE`, `AGENT_SCHEMA`, `AGENT_NAME`.
- Optional overrides: `AGENT_MESSAGE`, `AGENT_MESSAGES`, `AGENT_THREAD_ID`, `AGENT_PARENT_MESSAGE_ID`, `AGENT_TOOL_CHOICE`.
- Usage:

  ```bash
  export AGENT_DATABASE='SNOWFLAKE_SAMPLE_CORTEXAI_DB'
  export AGENT_SCHEMA='AGENTS'
  export AGENT_NAME='EMPLOYEE_AGENT'
  export SNOWFLAKE_ACCOUNT_URL='https://srsibdn-ura06696.snowflakecomputing.com'
  export SNOWFLAKE_PAT='***'
  ./scripts/local-cortex-agent.sh
  ```
