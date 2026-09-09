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

## M2 — Google Workspace expansion

Status: complete.

- [x] `get_email_attachment`
- [x] `search_drive_files`
- [x] `read_drive_file`
- [x] `get_calendar_events`
- [x] `find_free_time`
- [x] Restore both accepted Calendar tools simultaneously in the published `MCP — Server` surface
- [x] Rerun natural-language gateway regression request for `get_calendar_events`
- [x] Rerun natural-language gateway regression request for `find_free_time`

`get_email_attachment` is deployed as a read-only MCP tool. Gmail `attachmentId` is discovered internally and is never required from the user.

`search_drive_files` and `read_drive_file` are deployed through the dedicated Google Drive `drive.readonly` OAuth credential. Search, file reading, normalized errors, and natural cross-tool acceptance are complete.

`get_calendar_events` is deployed through the dedicated Google Calendar `calendar.readonly` OAuth credential. Low-level validation, provider 404 -> `NOT_FOUND`, audit lifecycle, and natural-language calendar queries are accepted.

`find_free_time` uses Google Calendar FreeBusy, validates per-calendar errors, merges busy intervals, computes qualifying free windows, finalizes audit state, and is accepted through natural-language MCP requests.

A Calendar gateway regression discovered on 2026-09-08 temporarily removed `get_calendar_events` from the aggregate MCP Server after `find_free_time` was added. The tool was restored and both Calendar tools are now present together in active MCP Server version `07843872-4ab5-46f1-8df9-9a6bc8418673`.

Final post-recovery natural-language regression acceptance passed on 2026-09-09:

- `get_calendar_events`: request for 2026-09-10 returned the source-accurate empty calendar; audit `succeeded`, `duration_ms=606`.
- `find_free_time`: request for a 60-minute slot on 2026-09-10 from 09:00 to 18:00 returned the source-accurate full free window; audit `succeeded`, `duration_ms=450`.

The regression is closed in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

During Drive acceptance, n8n `2.33.3` incorrectly routed a Google Drive 404 through the HTTP Request success output despite `Continue (using error output)`. Production was backed up and upgraded to `2.37.10`; the same 404 now follows the correct error branch and normalizes to `NOT_FOUND`.

## M3 — CRM integration

Status: next milestone.

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
