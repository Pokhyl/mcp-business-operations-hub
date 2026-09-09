# M3 KeyCRM manager customer statistics acceptance

Last verified: 2026-09-09.

## Goal

Add a read-only MCP capability for questions such as:

```text
Сколько всего клиентов у менеджера Анастасия Быкова?
```

The implementation must not scan the entire KeyCRM customer base per request and must not introduce CRM write access.

## Data model extension

`public.keycrm_customers` now stores the minimal additional field:

```text
manager_id bigint
```

An index was added:

```text
idx_keycrm_customers_manager_id
```

Migration:

```text
database/migrations/004_keycrm_manager_id.sql
```

The read-only PostgreSQL role remains read-only:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

## Backfill

The original successful full bootstrap execution `16711` already contained the KeyCRM `manager_id` values in the provider responses. Those verified responses were used once to backfill the existing index instead of consuming hundreds of additional KeyCRM API requests.

Bootstrap snapshot extraction:

```text
buyers:          24118
unique buyers:   24118
with manager_id: 21525
without manager: 2593
```

After applying the current incremental window, the production index contained:

```text
total customers:      24183
with manager_id:      21590
without manager_id:    2593
distinct manager IDs:    23
```

The permanent incremental synchronization was updated so every changed buyer now UPSERTs `manager_id` together with the existing minimal search fields.

Workflow:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
version_id: 3d9e505c-ce68-4bdd-9530-1c77838275e0
status: active
```

The one-time/full bootstrap normalizer was also updated so a future rebuild includes `manager_id` from the start.

## KeyCRM users endpoint

The official read-only KeyCRM users endpoint is used to resolve manager identities:

```text
GET /users
filter[status]=active
```

A production probe returned 22 active users. KeyCRM documents that user IDs are used as `manager_id` values.

## MCP tool

Workflow:

```text
MCP — KeyCRM Manager Customer Stats
workflow_id: KcrmMgrStatsA7pQ4Z
version_id: de05e569-d799-4bb4-b504-31d645447c18
status: active
```

Tool name:

```text
get_manager_customer_stats
```

Input:

```json
{
  "manager": "string"
}
```

Execution path:

```text
validate
 -> audit start
 -> GET active KeyCRM users
 -> resolve manager name
 -> read-only PostgreSQL count by manager_id
 -> normalize result
 -> audit finish
 -> return MCP response
```

Manager resolution supports Cyrillic/Latin transliteration and fuzzy full-name comparison. Ambiguous matches are rejected instead of silently selecting a manager.

Manager-name audit arguments are stored as `[REDACTED]`.

## Low-level production acceptance

Russian manager name:

```text
input:          Анастасия Быкова
resolved user:  Anastasiia Bykova
manager_id:     4
customer_count: 3383
success:        true
```

Negative cases:

```text
unknown manager -> NOT_FOUND
one-character input -> INVALID_INPUT
```

The success path reads the count through the existing `mcp_read` credential backed by PostgreSQL role `mcp_readonly`.

## MCP Server integration

Aggregate workflow:

```text
MCP — Server
workflow_id: dSohghXnQp078EZm
version_id: 0387a555-2f3b-4738-86ab-6bcda77ee838
active_version_id: 0387a555-2f3b-4738-86ab-6bcda77ee838
status: active
```

The complete published tool surface was re-verified after this edit:

```text
find_free_time
get_calendar_events
get_customer_details
get_email_attachment
get_github_file
get_job_details
get_manager_customer_stats
get_recent_jobs
read_drive_file
search_customers
search_drive_files
search_emails
```

No previously accepted tool was removed.

## Remaining acceptance

The low-level tool and aggregate gateway integration are accepted. A final natural-language request through the real MCP client should confirm that the client selects `get_manager_customer_stats` for a manager-count question and returns the source-accurate count.
