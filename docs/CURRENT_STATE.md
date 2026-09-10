# Current State

Last verified: 2026-09-10.

## Runtime

Production n8n runtime: `2.37.10`.

Production n8n:

```text
https://publisher.hodor.com.pl
```

## MCP gateway

Workflow: `MCP — Server`

```text
workflow_id:       dSohghXnQp078EZm
version_id:        3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
active_version_id: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
status:            active
```

Authentication: n8n OAuth2.

Current published tool surface:

```text
get_github_file
get_recent_jobs
get_job_details
search_emails
get_email_attachment
search_drive_files
read_drive_file
get_calendar_events
find_free_time
search_customers
get_customer_details
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

Total: 17 tools.

No production MCP workflow change was required for the 2026-09-10 M3 closure or the current M5 documentation/CI work.

## Milestones

```text
M0 Foundation                  complete
M1 Production cleanup          complete
M2 Google Workspace expansion  complete
M3 CRM integration             complete
M4 Controlled writes           deferred / not started
M5 Portfolio hardening         in progress
```

M3 was explicitly closed on 2026-09-10 with the current KeyCRM communications limitation accepted as a provider boundary.

On 2026-09-10 the user explicitly decided to close KeyCRM work for now and leave M4/write integrations for later. Therefore no further KeyCRM development, OAuth/write-scope changes, Gmail/Calendar writes, or CRM write tools should be started unless the user explicitly resumes that scope.

## M5 portfolio hardening progress

Completed on 2026-09-10 without changing production behavior:

```text
recruiter-facing README              complete
portfolio architecture diagram      complete (GitHub-rendered Mermaid)
sanitized portfolio examples        complete
automated n8n export validation     complete
deployment/operations runbook       complete
short demo video/GIF                remaining
```

Portfolio architecture:

```text
docs/PORTFOLIO_ARCHITECTURE.md
```

Sanitized examples:

```text
examples/README.md
```

Operations runbook:

```text
docs/RUNBOOK.md
```

Workflow export validation:

```text
scripts/validate_n8n_exports.py
.github/workflows/validate-n8n-exports.yml
```

The first GitHub Actions run of `Validate n8n exports` completed successfully against the current committed workflow exports.

The remaining M5 deliverable is a short demo video/GIF. Any demo must avoid exposing mailbox contents, customer PII, credentials/tokens, or confidential production metrics.

## M3 communications closure decision

The current official KeyCRM OpenAPI v1.2.0 does not expose a supported read resource for CRM-native communications/chats/messages/conversations.

The investigation established:

```text
public communications read endpoint: NOT AVAILABLE
buyer communications include:        NOT AVAILABLE
chat/message webhook event:           NOT AVAILABLE
```

`GET /buyer/{buyerId}` documents only these includes:

```text
manager
shipping
company
loyalty
custom_fields
```

The official outgoing webhook documentation currently exposes order/payment/lead-status events, not chat/message events.

Therefore `get_customer_communications` is intentionally not implemented. This is an accepted provider limitation for M3 closure, not an incomplete implementation item.

Required semantics remain:

```text
explicit Gmail/mailbox request
-> search_emails
-> Gmail

CRM-native communication/history request
-> current public KeyCRM API cannot supply it
-> report provider limitation
```

Do not silently substitute Gmail for KeyCRM-native history. Do not invent `/messages`, `/chats`, scrape the UI, or use private/internal KeyCRM endpoints as production architecture without a separate explicit architecture/security decision.

Evidence:

```text
docs/M3_KEYCRM_COMMUNICATIONS_API.md
docs/M3_KEYCRM_ACCEPTANCE.md
```

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

Valid audited calls follow:

```text
validate
-> audit start
-> provider/database read
-> normalize
-> audit finish
-> return original MCP response
```

Rules:

- `INVALID_INPUT` remains pre-audit.
- Finish-audit mappings omit `arguments_json` completely.
- Sensitive Gmail/customer/manager search inputs are redacted.
- Current user-facing CRM tools are read-only.

## KeyCRM customer index

KeyCRM remains the source of truth.

Table:

```text
public.keycrm_customers
```

Minimal fields:

```text
buyer_id
full_name
phones[]
emails[]
keycrm_updated_at
manager_id
synced_at
```

Permanent customer sync:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
status: active
schedule: every 15 minutes
```

`search_customers` uses the local index for natural name/email/phone/ID lookup. `get_customer_details` performs a fresh KeyCRM GET after a `buyer_id` is known.

Read-only PostgreSQL access uses credential `mcp_read`, backed by role `mcp_readonly`.

Verified business-read permissions remain:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

## KeyCRM manager analytics

Pipeline-card analytics use:

```text
public.keycrm_pipeline_cards
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
```

Observed assignment tracking uses:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

Permanent pipeline-card sync:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
status: active
schedule: every 15 minutes
```

The full bootstrap was reconciled against KeyCRM after shifting page boundaries caused 22 historical cards to be missed. The exact missing records were recovered and provider/local totals matched before manager analytics acceptance.

## Assignment-history limitation

KeyCRM UI stores an Action History, but the public KeyCRM OpenAPI does not expose the historical assignment action log used by the UI.

`get_manager_assignment_history` therefore remains snapshot-based from:

```text
tracking_started_at: 2026-09-09T18:37:30.384Z
```

It must not claim to know the historical initiator of a reassignment or reconstruct unsupported history before the tracking boundary.

## Gmail search

Workflow:

```text
MCP — Gmail Search
workflow_id: tUxRIiXHh2UaWflF
active_version_id: 98f525fe-84ed-486b-a013-163b5ad0f778
status: active
```

Zero-result behavior is fixed: Gmail returning no messages now produces `success=true`, `data=[]`, `count=0` rather than no MCP response.

The Gmail search query in audit start is stored as `[REDACTED]`.

Production export:

```text
n8n/gmail/SEARCH_EMAILS.json
```

`search_emails` remains a valid independent Gmail capability.

## Security state

- External credentials remain in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- Current KeyCRM user-facing tools use GET/read operations only.
- Internal synchronization writes only to local PostgreSQL infrastructure tables.
- Business-read tools use `mcp_readonly`.
- No unsupported KeyCRM communications endpoint was introduced.
- No M4 write credential/scope changes have been made.
- M5 changes so far are repository documentation/validation changes only; production runtime/workflows were not modified.

## Repository evidence

Key files:

```text
README.md
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/PORTFOLIO_ARCHITECTURE.md
docs/RUNBOOK.md
docs/MCP_TOOLS.md
docs/M3_KEYCRM_ACCEPTANCE.md
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
docs/M3_KEYCRM_COMMUNICATIONS_API.md
docs/NEXT_CHAT_HANDOFF_2026-09-10.md
examples/README.md
scripts/validate_n8n_exports.py
.github/workflows/validate-n8n-exports.yml
```

## Exact next step

Continue M5, not M4.

The remaining portfolio deliverable is the short demo video/GIF. Before recording, prepare a sanitized demo sequence that proves MCP behavior without exposing real mailbox contents, customer PII, credentials, or confidential CRM metrics.

M4 Controlled Writes remains explicitly deferred. Do not automatically start credential/scope changes, `send_email`, `create_calendar_event`, or a KeyCRM write operation.

If M4 is resumed later, first verify the actual production OAuth scopes/credentials separately from API capability. Existing read-only credentials must not be silently broadened.
