# Architecture

## Goal

Expose selected business capabilities to an AI client through a single controlled MCP gateway while keeping credentials, authorization, provider-specific logic, and implementation details inside self-hosted infrastructure.

## High-level design

```text
+------------------+
|   MCP Client     |
|     Claude       |
+--------+---------+
         |
         | MCP over HTTPS
         v
+----------------------------+
| n8n MCP Server Trigger     |
| OAuth2 authentication      |
+-------------+--------------+
              |
      tool selection by model
              |
   +----------+-----------+----------------+-------------------+------------------+
   |                      |                |                   |                  |
   v                      v                v                   v                  v
Gmail workflows       Drive workflows  Calendar workflows  GitHub workflow   CRM workflows
   |                      |                |                   |                  |
   v                      v                v                   v                  v
Gmail API             Drive API       Calendar API         GitHub API       KeyCRM API
                                                                                 |
                                                        +------------------------+------------------+
                                                        |                                           |
                                                        v                                           v
                                             PostgreSQL customer index                 PostgreSQL pipeline analytics
```

PostgreSQL content-job read tools remain a separate direct read path from the MCP gateway to PostgreSQL.

## Tool isolation

Every capability is implemented as an independent sub-workflow.

This provides:

1. explicit input contracts per tool;
2. separate least-privilege credentials per external system;
3. isolated provider validation and response normalization;
4. independent failure handling;
5. an aggregate MCP gateway that only exposes approved workflows.

The aggregate `MCP — Server` is a gateway surface, not a place for provider-specific business logic.

After every MCP Server edit, the complete expected tool set must be verified so adding one tool cannot silently remove another accepted tool.

## Google Drive read path

Drive access uses a dedicated OAuth2 credential with only:

```text
https://www.googleapis.com/auth/drive.readonly
```

The model-facing path is intentionally split into two tools:

```text
natural user request
 -> search_drive_files(query, limit)
 -> normalized file metadata + file_id
 -> read_drive_file(file_id)
 -> normalized text content
 -> model summarizes source content
```

`read_drive_file` chooses the provider operation from Drive metadata:

```text
Google Doc    -> Drive export text/plain
Google Sheet  -> Drive export text/csv
Google Slides -> Drive export text/plain
PDF           -> alt=media download -> text extraction
Text file     -> alt=media download -> text
Other binary  -> UNSUPPORTED_FILE_TYPE
```

Text output is capped at 50000 characters and carries explicit truncation metadata.

## Google Calendar read path

Calendar access uses a dedicated OAuth2 credential with only:

```text
https://www.googleapis.com/auth/calendar.readonly
```

Two separate tools are exposed:

```text
get_calendar_events -> event retrieval
find_free_time      -> FreeBusy query + free-window calculation
```

Both remain read-only and use normalized application-level errors.

## KeyCRM architecture

KeyCRM remains the CRM source of truth. The model-facing boundary exposes read tools only.

### Customer search path

KeyCRM `/buyer` does not provide a universal name-search filter. Production list filters are limited to buyer ID, phone, email, and time ranges, so scanning all buyer pages per natural-language request would be slow and rate-limit-heavy.

Therefore search and fresh detail retrieval are separated:

```text
search_customers(query, limit)
        |
        v
PostgreSQL minimal customer index
        |
        | returns buyer_id
        v
get_customer_details(buyer_id)
        |
        v
fresh GET /buyer/{buyer_id} from KeyCRM
```

Customer index table:

```text
public.keycrm_customers
```

Stored fields are intentionally minimal:

- `buyer_id`
- `full_name`
- `phones[]`
- `emails[]`
- `keycrm_updated_at`
- `manager_id`
- `synced_at`

Full CRM data such as notes, photos, conversations, and order history is not copied into the customer search index.

### Customer bootstrap

The customer bootstrap avoids unstable page-number scanning. It resolves the current maximum buyer ID, generates stable groups of 50 IDs, fetches those IDs from KeyCRM, UPSERTs each group, waits four seconds, and continues.

### Customer incremental synchronization

```text
Schedule every 15 minutes
 -> load last successful checkpoint
 -> subtract 2-minute overlap
 -> GET /buyer with filter[updated_between]
 -> paginate at 50 records/page
 -> wait 4000 ms between provider pages
 -> deduplicate by buyer_id
 -> UPSERT local index
 -> advance checkpoint only after successful write
```

Checkpoint table:

```text
public.keycrm_sync_state
```

The overlap provides at-least-once synchronization around the boundary; UPSERT by `buyer_id` makes repeats safe.

## KeyCRM manager analytics

Manager sales/lead analytics are based on KeyCRM pipeline cards, not `/order`.

### Why a second local index exists

Questions such as:

```text
Какая конверсия у Илоны за август?
Сколько заявок получила Илона и из каких каналов?
```

need aggregation across thousands of cards. Re-reading and paginating the complete KeyCRM dataset for every question would be slow and would consume provider rate limits.

Therefore pipeline cards are synchronized into a separate local analytics index:

```text
KeyCRM /pipelines/cards
        |
        | bootstrap + 15-minute incremental sync
        v
public.keycrm_pipeline_cards
        |
        +--> get_manager_sales_stats
        +--> get_manager_lead_stats
        +--> get_manager_assignment_history
```

Reference data is synchronized into:

```text
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
```

The pipeline-card index stores only fields needed for manager/source/status/time/value analytics, including:

```text
card_id
pipeline_id
source_id
manager_id
status_id/status_alias/status_title
created_at/updated_at/status_changed_at
payments_total/products_total
UTM fields
```

### Pipeline-card bootstrap integrity rule

The first global page-based bootstrap exposed a real consistency risk: new cards inserted while a long page scan is running can shift page boundaries. The workflow completed successfully, but provider/local count reconciliation found 22 historical records missing from the initial local snapshot.

The discrepancy was detected by comparing KeyCRM `created_between` counts against local counts, narrowed generically by month/week/day, then fetching and UPSERTing the exact missing provider records.

After reconciliation:

```text
provider total == local total == unique local card_id
```

This reconciliation result is part of production acceptance and must be repeated after any future full pipeline-card rebuild unless the bootstrap strategy is replaced with a stable partitioned scan.

### Pipeline-card incremental synchronization

Permanent path:

```text
Schedule every 15 minutes
 -> load pipeline_cards_incremental checkpoint
 -> subtract 2-minute overlap
 -> GET /pipelines/cards with filter[updated_between]
 -> paginate at limit=50 with 4000 ms request interval
 -> compare previous local manager_id/source_id
 -> record observed assignment/source changes
 -> UPSERT changed cards
 -> advance checkpoint after successful write
```

### Assignment history limitation

KeyCRM OpenAPI does not expose the historical assignment action log. Therefore old manager/source reassignment history cannot be reconstructed reliably.

The system stores observed snapshot differences from a documented boundary:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

`get_manager_assignment_history` returns the tracking boundary, observation cadence, and explicit coverage note. Multiple intermediate changes occurring entirely between two 15-minute polls may be collapsed into the final observed change.

### Call analytics

Call statistics and call timeline remain fresh KeyCRM reads rather than local-index analytics:

```text
manager name
 -> GET /users -> resolve manager_id
 -> GET /calls with manager_id + created_between
 -> get_manager_call_stats
    or
 -> get_manager_call_timeline -> calculate call-to-call gaps
```

The call-timeline tool calculates each positive break from the previous call end to the next call start.

## Read-only database boundary

Model-facing PostgreSQL reads use n8n credential `mcp_read`, backed by role `mcp_readonly`.

Verified business-read permissions are:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

Internal synchronization uses the application PostgreSQL credential because synchronization is infrastructure maintenance, not a model-facing business mutation.

## KeyCRM write boundary

The KeyCRM Bearer credential itself is not treated as a database-style read-only role. The boundary is enforced structurally: exposed CRM workflows perform GET/read operations only.

No KeyCRM POST/PATCH/PUT/DELETE operation is exposed through the current MCP surface.

## Response normalization

Raw provider responses are not sent directly to the model when they contain unnecessary provider metadata.

Read tools use the shared success/error envelope defined in `docs/CURRENT_STATE.md` and `docs/MCP_TOOLS.md`.

Provider-specific failures are converted into stable application-level codes such as:

- `INVALID_INPUT`
- `NOT_FOUND`
- `AMBIGUOUS_ATTACHMENT`
- `AMBIGUOUS_MANAGER`
- `UNSUPPORTED_FILE_TYPE`
- `UPSTREAM_ERROR`

## Read/write boundary

Current business read tools include:

- `search_emails`
- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_calendar_events`
- `find_free_time`
- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_customers`
- `get_customer_details`
- `get_manager_customer_stats`
- `get_manager_call_stats`
- `get_manager_sales_stats`
- `get_manager_lead_stats`
- `get_manager_assignment_history`
- `get_manager_call_timeline`

Future write examples remain a separate class:

- `send_email`
- `create_calendar_event`
- `update_customer`
- `upload_drive_file`

Write tools require an explicit approval boundary and idempotency protection where applicable.

## Audit pipeline

Execution path for valid audited calls:

```text
MCP request
 -> validate inputs
 -> audit start
 -> execute provider/database operation
 -> normalize result/error
 -> audit completion
 -> return original MCP tool response
```

`INVALID_INPUT` is intentionally rejected before audit/provider access.

Audit storage is implemented by `MCP — Audit Tool Call` and `database/migrations/001_mcp_tool_audit.sql`.

Finish-audit calls omit `arguments_json`. Sensitive search arguments such as Gmail queries and CRM customer/manager queries are redacted.

## Runtime compatibility rule

Workflow architecture must not absorb known runtime defects through ad-hoc branches when a supported runtime fix is available.

This rule was applied when n8n `2.33.3` misrouted HTTP 404 items through the HTTP Request success output. Production was backed up and upgraded to `2.37.10`; no workflow-specific error-detection bypass was added.

## M3 evidence

Detailed production evidence is recorded in:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`
- `docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md`
