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

Status: in progress.

- [x] Remove `hello_world`
- [x] Remove `get_person`
- [x] Add normalized tool response/error envelope
- [ ] Add centralized audit logging
- [ ] Redact sensitive audit arguments
- [ ] Add documented acceptance tests for all current tools

Manual regression/error-path checks have been completed for the current read tools, but the dedicated acceptance-test documentation is still pending.

## M2 — Google Workspace expansion

- [ ] `get_email_attachment`
- [ ] `search_drive_files`
- [ ] `read_drive_file`
- [ ] `get_calendar_events`
- [ ] `find_free_time`

## M3 — CRM integration

- [ ] Read-only customer search
- [ ] Customer details
- [ ] Cross-system customer context demo

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
