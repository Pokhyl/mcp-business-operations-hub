# Current State

Last verified: 2026-09-09.

## Runtime

Production n8n runtime: `2.37.10`.

Production was upgraded from `2.33.3` after a Google Drive HTTP error-output routing defect. A full backup was created before the upgrade and the post-upgrade regression passed.

## MCP gateway

Workflow: `MCP — Server`

```text
workflow_id:       dSohghXnQp078EZm
version_id:        0387a555-2f3b-4738-86ab-6bcda77ee838
active_version_id: 0387a555-2f3b-4738-86ab-6bcda77ee838
status:            active
```

Authentication: n8n OAuth2.

Current published tool surface:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`
- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_calendar_events`
- `find_free_time`
- `search_customers`
- `get_customer_details`
- `get_manager_customer_stats`

The complete tool surface was re-verified after the latest gateway edit; no previously accepted tool was removed.

## Milestones

- M0 — Foundation: complete
- M1 — Production cleanup: complete
- M2 — Google Workspace expansion: complete
- M3 — CRM integration: in progress / production read tools deployed

Detailed Calendar evidence is in `docs/CALENDAR_ACCEPTANCE.md`, `docs/FIND_FREE_TIME_ACCEPTANCE.md`, and `docs/ACCEPTANCE_TESTS.md`.

Detailed KeyCRM evidence is in:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`

## Normalized MCP contract

Success:

```json
{
  "success": true,
  "data": "...",
  "meta": {
    "tool": "...",
    "count": 1
  }
}
```

Error:

```json
{
  "success": false,
  "error": {
    "code": "...",
    "message": "..."
  },
  "meta": {
    "tool": "...",
    "count": 0
  }
}
```

Current error codes include `INVALID_INPUT`, `NOT_FOUND`, `AMBIGUOUS_ATTACHMENT`, `AMBIGUOUS_MANAGER`, `UNSUPPORTED_FILE_TYPE`, and `UPSTREAM_ERROR`.

Valid audited calls follow:

```text
validate
-> audit start
-> provider/database read
-> normalize
-> audit finish
-> return original MCP response
```

`INVALID_INPUT` remains pre-audit. Finish-audit calls omit `arguments_json`. Gmail/customer/manager search arguments that may contain PII are redacted.

## KeyCRM architecture

KeyCRM API base URL:

```text
https://openapi.keycrm.app/v1
```

Credential: `KeyCRM MCP` Bearer authentication.

KeyCRM remains the source of truth. MCP does not write to KeyCRM.

### Local customer index

Table:

```text
public.keycrm_customers
```

Minimal stored fields:

- `buyer_id`
- `full_name`
- `phones[]`
- `emails[]`
- `keycrm_updated_at`
- `manager_id`
- `synced_at`

The local index intentionally excludes orders, notes, photos, conversations, and other full CRM data.

Current production snapshot after the latest sync:

```text
total customers:       24186
with manager_id:       21593
without manager_id:     2593
```

Read-only PostgreSQL access uses n8n credential `mcp_read`, backed by role `mcp_readonly`:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

### Full bootstrap

Workflow:

```text
ADMIN — KeyCRM Customer Index Sync
workflow_id: KP1EPFbemTrxbkcY
```

The accepted first full bootstrap loaded `24118` unique customers with zero duplicate `buyer_id` values. The bootstrap normalizer now also stores `manager_id` for future rebuilds.

### Incremental sync

Workflow:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
version_id: 3d9e505c-ce68-4bdd-9530-1c77838275e0
status: active
schedule: every 15 minutes
```

It uses KeyCRM `filter[updated_between]`, `limit=50`, pagination, `4000 ms` between pages, a two-minute overlap on the previous successful checkpoint, deduplication by `buyer_id`, and UPSERT into the local index. `manager_id` is synchronized with every changed buyer.

Checkpoint table:

```text
public.keycrm_sync_state
```

Latest verified checkpoint:

```text
2026-09-09 12:45:05.187+00
last_count: 5
```

## KeyCRM MCP tools

### `search_customers`

Workflow: `MCP — KeyCRM Customer Search` (`yej0SNKc4Ovb4rzq`).

Searches the local read-only index by full/partial name, email, phone, or `buyer_id`.

A real natural-language MCP-client request successfully found the requested customer in CRM on 2026-09-09.

### `get_customer_details`

Workflow: `MCP — KeyCRM Customer Details` (`KcrmDetA9V7cQ2Lx`).

Takes a positive `buyer_id` and performs a fresh read from `GET /buyer/{buyer_id}`.

Accepted cases:

- existing buyer -> success
- missing buyer -> `NOT_FOUND`
- invalid buyer ID -> `INVALID_INPUT`

### `get_manager_customer_stats`

Workflow:

```text
MCP — KeyCRM Manager Customer Stats
workflow_id: KcrmMgrStatsA7pQ4Z
version_id: de05e569-d799-4bb4-b504-31d645447c18
status: active
```

Input:

```json
{
  "manager": "string"
}
```

The workflow reads active KeyCRM users through `GET /users`, resolves the manager name with Cyrillic/Latin transliteration-aware matching, then counts customers by `manager_id` using the read-only PostgreSQL credential.

Low-level production acceptance:

```text
input:          Анастасия Быкова
resolved user:  Anastasiia Bykova
manager_id:     4
customer_count: 3383
success:        true
```

Negative acceptance:

- unknown manager -> `NOT_FOUND`
- one-character input -> `INVALID_INPUT`

A final natural-language request through the real MCP client is still required for this new tool.

## Security state

- External credentials stay in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- KeyCRM user-facing tools perform GET/read operations only.
- Internal sync writes only to local PostgreSQL infrastructure tables.
- Business-read tools use the read-only PostgreSQL role.
- No write-capable business tool is exposed through MCP.

## Repository state

Key KeyCRM files:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`
- `database/migrations/003_keycrm_customer_index.sql`
- `database/migrations/004_keycrm_manager_id.sql`

## Exact next step

Run a natural-language MCP-client request for manager customer statistics, for example:

```text
Сколько всего клиентов у менеджера Анастасия Быкова?
```

The client should select `get_manager_customer_stats` and return the source-accurate count. After the client-level test passes, record it in acceptance documentation before moving on.
