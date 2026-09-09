# Next Chat Handoff — 2026-09-09

## Project

Repository: `Pokhyl/mcp-business-operations-hub`

Production n8n: `https://publisher.hodor.com.pl`
Runtime: n8n `2.37.10`

Aggregate MCP gateway:

```text
name: MCP — Server
workflow_id: dSohghXnQp078EZm
active_version_id: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
authentication: n8n OAuth2
status: active
```

Current published tools:

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

## Working rules

- Continue the existing production project. Do not redesign from scratch.
- GitHub documentation is the source of truth. Read `docs/CURRENT_STATE.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/MCP_TOOLS.md`, and this handoff before meaningful changes.
- Do not weaken security or quality gates.
- Keep exposed business tools read-only unless/ until M4 controlled writes is explicitly started.
- KeyCRM remains source of truth.
- Internal sync workflows may write only to local PostgreSQL infrastructure tables.
- User-facing PostgreSQL reads use credential `mcp_read`, backed by role `mcp_readonly`.
- `mcp_readonly` must remain SELECT-only on business-read tables.
- Every valid audited tool follows: validate -> audit start -> provider/database read -> normalize -> audit finish -> return.
- `INVALID_INPUT` remains pre-audit.
- On `Audit success` / `Audit failed`, remove `arguments_json` from finish mappings entirely; do not send blank `{}`.
- Sensitive search inputs must be redacted in audit start.
- When changing `MCP — Server`, verify the complete tool surface so no accepted tool disappears.
- Do not fabricate unsupported historical data.

## M0–M2

M0 Foundation: complete.
M1 Production cleanup: complete.
M2 Google Workspace expansion: complete.

Calendar regression was fully closed and both `get_calendar_events` and `find_free_time` are active.

## M3 — KeyCRM current state

M3 read-only CRM integration is nearly complete.

### Customer index

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

Permanent sync:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
schedule: every 15 minutes
```

KeyCRM `/buyer` name search limitation is why the local index exists. `search_customers` searches this index; `get_customer_details` retrieves a fresh record directly from KeyCRM.

### Manager analytics index

Main table:

```text
public.keycrm_pipeline_cards
```

Reference tables:

```text
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
```

Observed assignment tracking:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

Permanent sync:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
schedule: every 15 minutes
```

Initial pipeline-card bootstrap completed and post-bootstrap reconciliation repaired exactly 22 cards missed by shifting page boundaries. Final verified provider/local totals reached equality. Incremental sync continued to keep the index current.

### Manager tools already deployed

```text
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

All four newest analytics tools passed natural-language MCP client testing on 2026-09-09:

```text
Какая конверсия у Илоны за август?
Сколько заявок получила Илона в августе и из каких каналов?
Какие переназначения были у Илоны после начала отслеживания?
Какие перерывы между звонками делает Илона сегодня?
```

Example accepted August stats for Ilona Kamuz after full reconciliation:

```text
total_leads_raw:                  646
duplicate_leads:                  165
total_leads_excluding_duplicates: 481
successful_sales:                  76
conversion_percent_raw:           11.76
conversion_percent_excluding_duplicates: 15.80
successful_payments_total:      82760
```

Call timeline acceptance on 2026-09-09:

```text
total_calls:                    78
average_positive_gap_minutes:  4.5
longest_gap_minutes:          41.2
gaps_over_15_minutes:           6
gaps_over_30_minutes:           1
```

## Assignment-history limitation

KeyCRM UI has an Action History showing who changed fields, including manager changes. However, the public KeyCRM OpenAPI currently does not expose that historical action log, and current public webhooks do not provide a reliable change initiator for manager reassignment.

Therefore `get_manager_assignment_history` intentionally uses observed snapshots every 15 minutes and does not claim to know the initiator or reconstruct history before tracking started.

Tracking start currently documented as:

```text
2026-09-09T18:37:30.384Z
```

Do not try to invent old assignment history or the actor who made a change.

## Important discovery at end of current chat: customer communications architecture

The attempted final M3 cross-system demo exposed an architecture mistake.

The demo was initially designed as:

```text
search_customers
-> get_customer_details
-> take customer email
-> search_emails
-> read Gmail
```

That is valid only when the user explicitly asks about the connected Gmail mailbox. It is NOT the correct primary path for questions such as `покажи переписку с клиентом`.

The user pointed out that KeyCRM itself contains communication history, including emails and other connected customer channels. Therefore customer communication history should be CRM-first, not Gmail-first.

Current `search_emails` reads directly from Gmail via Gmail API. It does not read KeyCRM communication history.

### Gmail zero-result defect fixed

During the failed cross-system demo, `search_emails` returned no workflow response when Gmail matched zero messages. This was a real workflow defect.

Production fix:

```text
Get many messages (alwaysOutputData=true)
-> Has messages?
   true  -> Get a message -> normal response
   false -> Format MCP response with success=true, data=[], count=0
```

Audit start now stores Gmail query as `[REDACTED]`.

Production workflow:

```text
MCP — Gmail Search
workflow_id: tUxRIiXHh2UaWflF
active_version_id: 98f525fe-84ed-486b-a013-163b5ad0f778
status: active
```

Production n8n was restarted after publishing and health returned OK.

The current production export has been synchronized to:

```text
n8n/gmail/SEARCH_EMAILS.json
```

`search_emails` remains a valid independent Gmail capability. Do not remove it simply because CRM communications are being added.

## Exact next objective

Do NOT close M3 yet.

First determine what customer communications can be read from KeyCRM through supported, stable interfaces.

Research the current official KeyCRM API documentation and verify against the real connected account. Specifically determine whether there are supported read endpoints for:

```text
customer/lead communications
chat threads
messages
email messages stored in CRM
WhatsApp / Instagram / other connected channel messages
message direction
timestamps
manager/operator
buyer_id / lead_id relation
attachments if available
pagination and filters
```

Do not assume an endpoint exists based only on the KeyCRM UI. Verify official API support and then safely probe the real account with GET only.

If a supported API exists, design a universal read-only tool such as:

```text
get_customer_communications
```

Preferred conceptual input:

```json
{
  "buyer_id": 12345,
  "lead_id": 67890,
  "limit": 50
}
```

Exact contract must follow what the official API actually supports; do not invent parameters.

Preferred normalized result, only if supported by provider data:

```text
channel
created_at
direction
manager/operator
text
subject (for email, if available)
message/thread ids
related buyer/lead
attachment metadata
```

The model-facing request `покажи переписку с клиентом` should resolve the customer in KeyCRM and then query KeyCRM communications first. Gmail should remain a separate source for explicit Gmail/mailbox questions or as an additional source only when the user's request calls for it.

If official KeyCRM API does NOT expose communications, document that limitation clearly before considering any private/internal UI endpoint. Do not silently scrape or rely on unstable internal endpoints as production architecture.

## M3 closure condition revised

M3 should close only after:

1. The CRM-native communications capability is either implemented through a supported API and natural-language tested, OR its official API unavailability is conclusively documented.
2. The final customer-context demo uses the correct architecture.
3. GitHub docs and workflow exports are synchronized.

A good final demo, if CRM communications are available, is:

```text
Найди клиента <name> в CRM, покажи его актуальные данные и последние сообщения/переписку с ним.
```

Expected chain:

```text
search_customers
-> get_customer_details
-> get_customer_communications
-> one combined CRM-grounded answer
```

Gmail should not be forced into this chain unless the user explicitly asks for Gmail/email outside the CRM communication history.

## After M3

M4 Controlled Writes remains future work:

```text
separate write-tool class
explicit user approval
idempotency
send_email
create_calendar_event
one safe CRM write
```

Do not start M4 until M3 communications/context behavior is resolved and accepted.
