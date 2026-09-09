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

Status: in progress; production read tools deployed.

- [x] Select KeyCRM and define the read-only boundary
- [x] Create local PostgreSQL customer search index
- [x] Complete one-time KeyCRM bootstrap
- [x] Add scheduled incremental synchronization with `updated_between`
- [x] Keep KeyCRM as source of truth and store only minimal search fields locally
- [x] `search_customers(query, limit)`
- [x] `get_customer_details(buyer_id)`
- [x] Add `manager_id` to the local search index
- [x] Synchronize `manager_id` in full and incremental paths
- [x] `get_manager_customer_stats(manager)`
- [x] Resolve manager names through KeyCRM `GET /users`
- [x] Support Cyrillic/Latin manager-name matching without hard-coded manager aliases
- [x] Keep manager statistics on the read-only PostgreSQL credential
- [x] Expose all CRM read tools through the aggregate `MCP — Server`
- [x] Verify the full M0-M3 tool surface after each gateway edit
- [x] Natural-language client search for a customer
- [ ] Natural-language client acceptance for `get_manager_customer_stats`
- [ ] Final cross-system customer context demo and M3 closure

Current production gateway includes:

```text
search_customers
get_customer_details
get_manager_customer_stats
```

Detailed evidence:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`

## M4 — Controlled writes

- [ ] Separate write-tool class
- [ ] Explicit user approval requirement
- [ ] Idempotency for mutations
- [ ] `send_email`
- [ ] `create_calendar_event`
- [ ] one CRM write operation

## M5 — Portfolio hardening

- [ ] Architecture diagram image
- [ ] Short demo video/GIF
- [ ] Sanitized example executions
- [ ] Automated workflow JSON validation
- [ ] Deployment/runbook documentation
- [ ] Final recruiter-facing README
