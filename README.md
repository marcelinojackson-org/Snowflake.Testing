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

### scripts/local-aisql.sh

- Builds `../Snowflake.Common` and `../Snowflake.AISQLAction`, then runs a basic pass across all AISQL functions using minimal inputs.
- Prerequisites:
  - Cortex AI must be enabled for the account and your role/user.
  - Required env vars (Snowflake connection + role) must be set before running.
  - For AI_PARSE_DOCUMENT, the document must be staged in Snowflake and you must provide either a staged file path (`AI_PARSE_DOCUMENT_FILE`) or a SQL file object (`AI_PARSE_DOCUMENT_FILE_OBJECT`).
- Required env: `SNOWFLAKE_ACCOUNT` or `SNOWFLAKE_ACCOUNT_URL`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD` or `SNOWFLAKE_PRIVATE_KEY_PATH`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_SCHEMA`.
- Optional: `AI_PARSE_DOCUMENT_FILE` (staged file path like `@~/docs/invoice.pdf`), `AI_PARSE_DOCUMENT_FILE_OBJECT` (raw SQL file object like `TO_FILE('@~/docs/invoice.pdf')`), or legacy `AI_PARSE_DOCUMENT`.
- Optional (advanced mode): `RUN_AISQL_ADVANCED=1` to run additional variants.
- Optional (advanced mode file inputs): `AI_EXTRACT_FILE_OBJECT`, `AI_EMBED_INPUT_FILE_OBJECT`, `AI_SIMILARITY_INPUT1_FILE_OBJECT`, `AI_SIMILARITY_INPUT2_FILE_OBJECT`.
- Optional (advanced mode config): `AI_CLASSIFY_CONFIG_OBJECT` (JSON object string).
- Optional: `USE_CORTEX_NAMES=1` to run `SNOWFLAKE.CORTEX.*` function names when your account supports them.
- The script skips AI_PARSE_DOCUMENT when given a local filesystem path (it expects staged files).
- If you see `User access disabled`, your Snowflake user/role or account does not have Cortex AI enabled.
- Usage:

  ```bash
  ./scripts/local-aisql.sh

  # override repo locations if needed
  COMMON_REPO_DIR=~/dev/Snowflake.Common \
  AISQL_REPO_DIR=~/dev/Snowflake.AISQLAction \
  ./scripts/local-aisql.sh

  # provide a file for AI_PARSE_DOCUMENT
  AI_PARSE_DOCUMENT_FILE="TO_FILE('@docs/invoice.pdf')" \
  ./scripts/local-aisql.sh

  # run advanced variants
  RUN_AISQL_ADVANCED=1 \
  ./scripts/local-aisql.sh
  ```

- Sample results (abbreviated):

  | Function | Example result |
  | --- | --- |
  | `AI_COMPLETE` | `"This repository contains a collection of Python scripts..."` |
  | `AI_EXTRACT` | `{"order_id":"18422","city":"Denver","date":"2024-02-01","amount":"$412.50"}` |
  | `AI_SENTIMENT` | `{"categories":[{"name":"overall","sentiment":"mixed"}]}` |
  | `AI_CLASSIFY` | `{"labels":["billing"]}` |
  | `AI_COUNT_TOKENS` | `128` |
  | `AI_EMBED` | `"[-0.008211,0.020005,...]"` |
  | `AI_SIMILARITY` | `0.8151` |
  | `SNOWFLAKE.CORTEX.SUMMARIZE` | `"This test script validates the AISQL action..."` |
  | `AI_TRANSLATE` | `"Hola Mundo"` |
  | `AI_PARSE_DOCUMENT` | `{"text":"...","tables":[...],"pages":[...]}` (when staged file provided) |

- Advanced sample results (abbreviated):
  - `AI_COMPLETE` with model params: `{"choices":[{"messages":"..."}],"usage":{"total_tokens":311}}`
  - `AI_COUNT_TOKENS` with model name: `18`
