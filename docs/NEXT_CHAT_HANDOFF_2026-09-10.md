# Next Chat Handoff — 2026-09-10

## Project

```text
Pokhyl/mcp-business-operations-hub
```

This is an existing production project. Do not restart it or perform a new general architecture audit.

GitHub is the source of truth. If chat history or a VPS checkout disagrees with the connected GitHub repository, trust GitHub.

## Read first

```text
docs/CURRENT_STATE.md
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/PORTFOLIO_ARCHITECTURE.md
docs/MCP_TOOLS.md
docs/SECURITY.md
docs/RUNBOOK.md
examples/README.md
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

Current published MCP tool surface remains 17 read-only tools:

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

No production workflow was changed during the current M5 work.

## Milestone status

```text
M0 Foundation                  complete
M1 Production cleanup          complete
M2 Google Workspace expansion  complete
M3 CRM integration             complete
M4 Controlled writes           deferred / not started
M5 Portfolio hardening         in progress
```

M3 is closed. The missing public KeyCRM communications API is an accepted provider limitation, not an unfinished M3 task.

M4 is explicitly deferred. Do not resume KeyCRM development, write credentials/scopes, Gmail/Calendar writes, or CRM mutations unless the user explicitly reopens M4.

## M5 completed in this pass

### Recruiter-facing README

`README.md` was rewritten to reflect the actual current project rather than the old M2/7-tool state.

It now presents:

- 17 production read-only MCP tools;
- n8n/PostgreSQL/OAuth2/Google Workspace/GitHub/KeyCRM stack;
- architecture and security boundaries;
- synchronization/read-model design;
- real classes of production defects caught during acceptance;
- explicit KeyCRM provider limitations;
- current M0-M5 milestone status.

### Portfolio architecture

Created:

```text
docs/PORTFOLIO_ARCHITECTURE.md
```

It contains a GitHub-rendered Mermaid architecture diagram plus concise recruiter/interview-level explanation of the gateway, isolated tool workflows, APIs, PostgreSQL read models, internal sync, audit path, credential boundary, and KeyCRM limitation.

### Sanitized portfolio examples

Created:

```text
examples/README.md
```

Examples cover Gmail, Drive, Calendar, job diagnosis, customer lookup, manager analytics, call timeline, and the correct provider-limitation behavior. PII and real business metrics are not published; representative demo values are explicitly marked synthetic.

### Automated workflow JSON validation

Created:

```text
scripts/validate_n8n_exports.py
.github/workflows/validate-n8n-exports.yml
```

The dependency-free validator checks all `n8n/**/*.json` exports for valid JSON and core workflow structure, including node uniqueness and connection references.

GitHub Actions run `Validate n8n exports` run #1 completed successfully on the current exports.

### Deployment/operations runbook

Created:

```text
docs/RUNBOOK.md
```

It records source-of-truth rules, safe workflow release sequence, health/acceptance/audit requirements, database migration boundaries, sync integrity rules, runtime-change procedure, rollback principles, M4 deferral, and CI validation.

## Remaining M5 work

Only the planned short demo video/GIF remains incomplete in the roadmap.

Do not fake a production demo with invented data. The next step is to prepare/use a sanitized recording sequence that demonstrates real MCP behavior without exposing:

```text
mailbox contents
customer PII
credentials/tokens
confidential CRM metrics
```

The video/GIF should be short and recruiter-facing rather than a full technical walkthrough.

## Retained security/read-only rules

- Current model-facing business tools remain read-only.
- KeyCRM remains source of truth.
- Internal sync may write only to local PostgreSQL infrastructure tables.
- Model-facing PostgreSQL credential maps to `mcp_readonly`.
- `mcp_readonly` remains SELECT-only on business-read tables.
- `INVALID_INPUT` remains pre-audit.
- Finish-audit mappings omit `arguments_json` entirely.
- Sensitive search arguments remain redacted.
- Do not remove existing MCP tools.
- After any MCP Server edit, verify the complete tool surface.
- Do not invent unsupported provider endpoints.

## Production change sequence

After any future production workflow change:

```text
inspect
-> modify
-> deploy/publish
-> health check
-> low-level test
-> audit check
-> natural-language E2E when relevant
-> verify complete gateway surface when applicable
-> export exact production workflow
-> sync GitHub
```

Do not leave production newer than GitHub and do not trust a stale dirty VPS checkout over connected GitHub.
