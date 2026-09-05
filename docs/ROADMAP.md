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

- [x] Remove `hello_world`
- [x] Remove `get_person`
- [x] Add normalized tool response/error envelope
- [x] Add centralized audit logging
- [x] Redact sensitive audit arguments
- [x] Add documented acceptance tests for all current tools

Centralized audit logging is deployed through `MCP — Audit Tool Call` and wired into the current read tools.

Audit argument redaction is centralized before PostgreSQL storage. Gmail search queries are always redacted, credential/session-style argument keys are recursively redacted, and historical raw Gmail audit queries were backfilled with migration `002_redact_existing_email_audit_queries.sql`.

Production acceptance evidence and regression rules are documented in `docs/ACCEPTANCE_TESTS.md`.

## M2 — Google Workspace expansion

- [x] `get_email_attachment`
- [ ] `search_drive_files`
- [ ] `read_drive_file`
- [ ] `get_calendar_events`
- [ ] `find_free_time`

`get_email_attachment` is deployed as a read-only MCP tool. The public contract is `message_id` plus optional `filename`; Gmail `attachmentId` is discovered internally and is never required from the user. A single attachment is selected automatically. If several attachments are present, the tool returns available filenames so the agent can retry with `filename`.

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
