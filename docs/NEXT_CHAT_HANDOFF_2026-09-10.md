# Next Chat Handoff — 2026-09-10

## Project

```text
Pokhyl/mcp-business-operations-hub
```

This is an existing production project. Do not restart it or perform a new general architecture audit.

GitHub is the source of truth. If chat history or a VPS checkout disagrees with the connected GitHub repository, trust GitHub.

## Read first

Before continuing, read:

```text
docs/CURRENT_STATE.md
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/MCP_TOOLS.md
docs/M3_KEYCRM_ACCEPTANCE.md
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
docs/M3_KEYCRM_COMMUNICATIONS_API.md
```

## Production

```text
n8n:    https://publisher.hodor.com.pl
runtime: 2.37.10
```

MCP Server:

```text
workflow_id: dSohghXnQp078EZm
active_version: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
authentication: n8n OAuth2
status: active
```

Current published MCP tool surface remains 17 tools:

```text
get_github_file
get_recent_jobs
get_job_details
search_emails
get_email_attachment
search_drive_files
read_drive_file
find_free_time
get_calendar_events
search_customers
get_customer_details
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

## Milestone status

```text
M0 Foundation                 complete
M1 Production cleanup         complete
M2 Google Workspace expansion complete
M3 CRM integration            complete
M4 Controlled writes          not started / unblocked
M5 Portfolio hardening        not started
```

M3 was explicitly closed on 2026-09-10.

## M3 closure boundary

The current official KeyCRM OpenAPI v1.2.0 does not expose CRM-native communications/chats/messages/conversations through a supported public read endpoint.

Investigation result:

```text
public communications read endpoint: NOT AVAILABLE
buyer communications include:        NOT AVAILABLE
chat/message webhook event:           NOT AVAILABLE
```

`get_customer_communications` was intentionally not implemented. This is an accepted provider limitation, not an unfinished M3 task.

Required semantics remain:

```text
explicit Gmail/mailbox request
-> search_emails
-> Gmail

CRM-native communication/history request
-> current public KeyCRM API cannot supply it
-> report provider limitation
```

Do not silently substitute Gmail for CRM-native history. Do not invent KeyCRM `/messages` or `/chats` endpoints, scrape the KeyCRM UI, or use private/internal UI APIs without a separate explicit architecture/security decision.

## Existing CRM state

Customer index:

```text
public.keycrm_customers
```

Permanent customer sync:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
schedule: every 15 minutes
```

Manager analytics tables:

```text
public.keycrm_pipeline_cards
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

Permanent pipeline-card sync:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
schedule: every 15 minutes
```

Assignment-history tracking boundary:

```text
2026-09-09T18:37:30.384Z
```

Do not infer historical initiators or pre-tracking assignment history.

## Security/read-only rules retained

- KeyCRM remains source of truth.
- Existing user-facing CRM tools remain read-only.
- Internal sync may write only to local PostgreSQL infrastructure tables.
- Model-facing PostgreSQL credential `mcp_read` maps to `mcp_readonly`.
- `mcp_readonly` remains SELECT-only on business-read tables.
- `INVALID_INPUT` remains pre-audit.
- Finish-audit mappings omit `arguments_json` entirely.
- Sensitive search arguments remain redacted.
- Do not remove existing MCP tools.
- After any MCP Server edit, verify the complete tool surface.

## Next milestone

M4 Controlled Writes is now unblocked but has not started.

Planned M4 scope from the roadmap:

```text
separate write-tool class
explicit user approval
idempotency
send_email
create_calendar_event
one safe CRM write operation
```

Do not weaken existing read-only tools when introducing M4. Write tools must be separated by an explicit approval boundary and use idempotency where applicable.

After any production workflow change:

```text
inspect
-> modify
-> deploy/publish
-> health check
-> low-level test
-> audit check
-> natural-language E2E when relevant
-> export exact production workflow
-> sync GitHub
```

Do not leave production newer than GitHub and do not trust a stale dirty VPS checkout over connected GitHub.
