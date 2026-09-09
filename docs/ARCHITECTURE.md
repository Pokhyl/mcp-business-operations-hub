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
                                                                                 | incremental read sync
                                                                                 v
                                                                       PostgreSQL customer index
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

The aggregate `MCP — Server` is treated as a gateway surface, not as a place for provider-specific business logic.

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

### Why a local index exists

KeyCRM remains the CRM source of truth, but its `/buyer` endpoint does not provide a universal name-search filter. The allowed list filters observed in production are limited to buyer ID, phone, email, and updated/created ranges.

Scanning all customer pages for every natural-language name search would be slow, rate-limit-heavy, and unstable while the dataset changes.

Therefore M3 separates **search** from **fresh detail retrieval**:

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

### Local index contents

Table:

```text
public.keycrm_customers
```

Only search-oriented fields are stored:

- `buyer_id`
- `full_name`
- `phones[]`
- `emails[]`
- `keycrm_updated_at`
- `synced_at`

Full CRM data such as orders, notes, photos, and conversations is not copied into the local search index.

### Bootstrap

The one-time bootstrap avoids normal page-number scanning. It first resolves the current maximum buyer ID, generates stable groups of 50 IDs, fetches those specific IDs through KeyCRM, UPSERTs each group immediately, waits four seconds, and continues.

This makes progress durable and avoids record shifts caused by concurrent CRM inserts while the initial load is running.

### Incremental synchronization

Permanent workflow:

```text
Schedule every 15 minutes
 -> load last successful checkpoint
 -> subtract 2-minute overlap
 -> GET /buyer with filter[updated_between]
 -> paginate at 50 records/page
 -> wait 4000 ms between provider pages
 -> deduplicate by buyer_id
 -> UPSERT local index
 -> advance checkpoint only after successful data write
```

Checkpoint table:

```text
public.keycrm_sync_state
```

The overlap deliberately makes synchronization at-least-once around the boundary; UPSERT by `buyer_id` makes repeated rows safe.

### Read-only search boundary

`search_customers` uses the n8n credential `mcp_read`, backed by PostgreSQL role `mcp_readonly`.

For the CRM index this role is verified as:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

The internal synchronization workflow uses the application PostgreSQL credential because synchronization is infrastructure maintenance, not a model-facing business mutation.

### KeyCRM write boundary

The KeyCRM Bearer credential itself is not treated as a database-style read-only role. The M3 boundary is enforced structurally: exposed CRM workflows perform only GET requests.

No KeyCRM POST/PATCH/PUT/DELETE operation is exposed through M3 MCP tools.

## Response normalization

Raw provider responses are not sent directly to the model when they contain unnecessary provider metadata.

Read tools use the shared success/error envelope defined in `docs/CURRENT_STATE.md` and `docs/MCP_TOOLS.md`.

Provider-specific failures are converted into stable application-level codes such as:

- `INVALID_INPUT`
- `NOT_FOUND`
- `AMBIGUOUS_ATTACHMENT`
- `UNSUPPORTED_FILE_TYPE`
- `UPSTREAM_ERROR`

## Read/write boundary

### Read tools

Current read tools include:

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

These do not mutate business state.

### Write tools

Future examples:

- `send_email`
- `create_calendar_event`
- `update_customer`
- `upload_drive_file`

Write tools must be a separate tool class with an explicit approval boundary and idempotency protection where applicable.

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

Finish-audit calls omit `arguments_json`. Sensitive search arguments such as Gmail queries and CRM customer queries are stored redacted.

## Runtime compatibility rule

Workflow architecture must not absorb known runtime defects through ad-hoc branches when a supported runtime fix is available.

This rule was applied when n8n `2.33.3` misrouted HTTP 404 items through the HTTP Request success output. Production was backed up and upgraded to `2.37.10`; no workflow-specific error-detection bypass was added.

## M3 evidence

Detailed production evidence is recorded in `docs/M3_KEYCRM_ACCEPTANCE.md`.
