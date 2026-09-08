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

Status: in progress — final post-recovery gateway regression acceptance pending.

- [x] `get_email_attachment`
- [x] `search_drive_files`
- [x] `read_drive_file`
- [x] `get_calendar_events`
- [x] `find_free_time`
- [x] Restore both accepted Calendar tools simultaneously in the published `MCP — Server` surface
- [ ] Rerun one natural-language gateway regression request for `get_calendar_events`
- [ ] Rerun one natural-language gateway regression request for `find_free_time`

`get_email_attachment` is deployed as a read-only MCP tool. The public contract is `message_id` plus optional `filename`; Gmail `attachmentId` is discovered internally and is never required from the user.

`search_drive_files` is deployed with a dedicated Google Drive `drive.readonly` OAuth credential and supports natural filename/full-text search with normalized metadata results.

`read_drive_file` is deployed and supports Google Docs, Sheets, Slides, PDF, and text files. Low-level and natural-language cross-tool acceptance are complete.

`get_calendar_events` implementation, low-level acceptance, audit verification, MCP exposure, and natural-language client acceptance are complete. Natural-language checks covered week, month, and year windows against the real primary calendar.

`find_free_time` is implemented with Google Calendar FreeBusy, published, exposed, and accepted through a natural-language MCP client request. A real request for a 60-minute slot on 2026-09-09 from 09:00 to 18:00 produced the expected free window and a succeeded audit row with `duration_ms=640`.

A Calendar gateway regression found during post-acceptance inspection on 2026-09-08 has been structurally recovered: `get_calendar_events` and `find_free_time` are again present together in the same active `MCP — Server` version (`07843872-4ab5-46f1-8df9-9a6bc8418673`), both are connected to `MCP Server Trigger`, and `n8n/MCP_SERVER.json` has been synchronized with that recovered production surface. The regression remains open only for the two final natural-language post-recovery checks documented in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

During Drive acceptance, n8n `2.33.3` incorrectly routed a Google Drive 404 through the HTTP Request success output despite `Continue (using error output)`. Production was backed up and upgraded to `2.37.10`; the same 404 now follows the correct error branch and normalizes to `NOT_FOUND`.

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
