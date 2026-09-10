# Roadmap

## M0 — Foundation

Status: complete.

- [x] MCP endpoint deployed in n8n
- [x] OAuth2 authentication for MCP client
- [x] GitHub read tool
- [x] PostgreSQL recent jobs tool
- [x] PostgreSQL job details tool
- [x] Gmail search + full body tool
- [x] Export working workflows to dedicated project repository
- [x] Create architecture/security/tool documentation
- [x] Publish dedicated GitHub repository

## M1 — Production cleanup

Status: complete.

- [x] Remove legacy test tools
- [x] Add normalized response/error envelope
- [x] Add centralized audit logging
- [x] Redact sensitive audit arguments
- [x] Add documented acceptance tests

## M2 — Google Workspace expansion

Status: complete.

- [x] `get_email_attachment`
- [x] `search_drive_files`
- [x] `read_drive_file`
- [x] `get_calendar_events`
- [x] `find_free_time`
- [x] Verify the complete gateway surface after Calendar recovery
- [x] Rerun natural-language Calendar regression requests

Detailed M2 evidence is recorded in the Calendar, Drive, and acceptance documents.

## M3 — CRM integration

Status: complete as of 2026-09-10.

M3 was closed with the current KeyCRM CRM-native communications limitation explicitly accepted as a provider boundary. The current public KeyCRM OpenAPI v1.2.0 does not expose a supported communications/chat/message read resource, buyer communications include, or documented chat/message webhook event. No private/UI workaround is part of M3.

- [x] Select KeyCRM and define the read-only boundary
- [x] Create local PostgreSQL customer search index
- [x] Complete one-time KeyCRM customer bootstrap
- [x] Add scheduled customer incremental synchronization with `updated_between`
- [x] Keep KeyCRM as source of truth and store only minimal search fields locally
- [x] `search_customers(query, limit)`
- [x] `get_customer_details(buyer_id)`
- [x] Add `manager_id` to the local customer index
- [x] Synchronize `manager_id` in full and incremental paths
- [x] `get_manager_customer_stats(manager)`
- [x] Resolve manager names through KeyCRM `GET /users`
- [x] Support Cyrillic/Latin manager-name matching without hard-coded aliases
- [x] Keep manager statistics on the read-only PostgreSQL credential
- [x] Natural-language client acceptance for `get_manager_customer_stats`
- [x] `get_manager_call_stats(manager, start, end)`
- [x] Create local pipeline-card analytics index
- [x] Reconcile bootstrap count against live KeyCRM and repair the 22 missing historical cards
- [x] Add permanent 15-minute pipeline-card incremental synchronization
- [x] Add observed manager/source reassignment tracking from a documented start boundary
- [x] `get_manager_sales_stats(manager, start, end)`
- [x] `get_manager_lead_stats(manager, start, end)`
- [x] `get_manager_assignment_history(manager, start, end)`
- [x] `get_manager_call_timeline(manager, start, end)`
- [x] Expose all current CRM read tools through the aggregate `MCP — Server`
- [x] Verify the full M0-M3 tool surface after the latest gateway edit
- [x] Low-level production acceptance for manager analytics tools
- [x] Natural-language MCP-client acceptance for manager analytics tools
- [x] Fix `search_emails` zero-result behavior and redact Gmail search audit query
- [x] Investigate official/stable KeyCRM customer communications access — unsupported by current public OpenAPI v1.2.0
- [x] Investigate documented KeyCRM webhook message-event fallback — no supported chat/message event
- [x] Accept `get_customer_communications` as not implementable through the current supported provider API; do not use guessed/private UI APIs
- [x] Define final customer-context behavior: generic CRM communication-history requests report the provider limitation and do not silently substitute Gmail
- [x] Close M3 with the provider limitation documented and accepted

Current production CRM gateway includes:

```text
search_customers
get_customer_details
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

Architecture boundary retained after M3 closure:

```text
"show communication/history with this customer"
-> resolve customer in KeyCRM
-> use KeyCRM-native communications only if/when a supported public interface exists
-> otherwise report the provider limitation; do not silently route to Gmail
```

`search_emails` remains a separate Gmail capability for explicit Gmail/mailbox questions.

Evidence:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`
- `docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md`
- `docs/M3_KEYCRM_COMMUNICATIONS_API.md`

## M4 — Controlled writes

Status: deferred by explicit user decision on 2026-09-10; not started.

M4 remains planned for a later phase. Do not start credential/scope changes, Gmail/Calendar writes, or KeyCRM write operations until the user explicitly resumes M4.

- [ ] Separate write-tool class
- [ ] Explicit user approval requirement
- [ ] Idempotency for mutations
- [ ] `send_email`
- [ ] `create_calendar_event`
- [ ] one safe CRM write operation

## M5 — Portfolio hardening

Status: in progress as of 2026-09-10.

- [x] Recruiter-facing architecture diagram using GitHub-rendered Mermaid (`docs/PORTFOLIO_ARCHITECTURE.md`)
- [ ] Short demo video/GIF
- [x] Sanitized example executions (`examples/README.md`)
- [x] Automated workflow JSON validation (`scripts/validate_n8n_exports.py` + GitHub Actions)
- [x] Deployment/runbook documentation (`docs/RUNBOOK.md`)
- [x] Final recruiter-facing README

The automated workflow export validation is active on push and pull request and passed its first run on the current repository exports.

The remaining M5 deliverable is the short demo video/GIF. It must avoid exposing mailbox content, customer PII, credentials, or confidential production metrics.
