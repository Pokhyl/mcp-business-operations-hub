# Current State

Last verified: 2026-09-05.

## Deployed MCP gateway

Workflow: `MCP — Server`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current production tool surface:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`
- `get_email_attachment`

Legacy tools `hello_world` and `get_person` have been removed from the deployed MCP server.

## Milestone status

M1 — Production cleanup: complete.

M2 — Google Workspace expansion: in progress.

Completed M2 item:

- `get_email_attachment`

Next M2 item:

- `search_drive_files`

No write-capable behavior is exposed in M2.

## Normalized MCP contract

Read tools use the common success envelope:

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

Errors use:

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

Current normalized error codes include:

- `INVALID_INPUT`
- `NOT_FOUND`
- `AMBIGUOUS_ATTACHMENT`
- `UPSTREAM_ERROR`

## Centralized audit logging

Audit workflow: `MCP — Audit Tool Call`

Audit table: `mcp_tool_calls`

Lifecycle for valid audited calls:

```text
Validate input
 -> Audit start
 -> Provider/database operation
 -> Normalize success/error
 -> Audit finish
 -> Return original MCP response
```

`Audit start` stores sanitized arguments and returns `audit_id` plus `started_at`. `Audit finish` finalizes the same row with `succeeded|failed`, normalized error data, duration, and completion timestamp.

`INVALID_INPUT` remains before `Audit start` and therefore does not create an audit row.

Sensitive-argument sanitization remains centralized in `MCP — Audit Tool Call`. Gmail search queries are always stored as `[REDACTED]`; credential/session-style keys are recursively redacted. Historical raw Gmail-query audit values were backfilled by `database/migrations/002_redact_existing_email_audit_queries.sql`.

All finish-audit subworkflow calls omit `arguments_json`; only audit start writes call arguments.

## Gmail

### `search_emails`

Workflow: `MCP — Gmail Search`

Status: active.

Inputs:

- `query` — required non-empty Gmail search string
- `limit` — optional integer, default `5`, range `1..50`

The Gmail search query is passed through `filters.q`. Output messages include `id`, `threadId`, `from`, `to`, `subject`, `date`, and `body`.

### `get_email_attachment`

Workflow: `MCP — Gmail Attachment`

Status: active and exposed through `MCP — Server`.

Public inputs:

- `message_id` — required; normally obtained internally from `search_emails`
- `filename` — optional exact or partial filename hint

The user is never required to know or provide Gmail `attachmentId`.

Current flow:

```text
When Executed by Another Workflow
 -> Validate input
 -> Is input valid?
    -> false: INVALID_INPUT
    -> true: Audit start
       -> Get message metadata (Gmail format=full)
          -> Error: normalized Gmail UPSTREAM_ERROR
          -> Success: Find attachment
             -> recursively traverse MIME parts
             -> discover body.attachmentId internally
             -> prefer explicit Content-Disposition: attachment parts
             -> if one candidate: select automatically
             -> if filename supplied: exact match, then partial match
             -> if several candidates remain: AMBIGUOUS_ATTACHMENT + available filenames
             -> if no candidate matches: NOT_FOUND
             -> selected: Get attachment data
                -> Error: normalized Gmail UPSTREAM_ERROR
                -> Success: convert Gmail base64url to standard base64
                   -> Format MCP response
                   -> Audit success
                   -> Return MCP response
```

Successful public output contains:

- `filename`
- `mime_type`
- `size`
- `content_base64`

The internal Gmail `attachmentId` is not returned in the public success response.

Production end-to-end verification used a real Gmail message with one PNG attachment. The tool was called with only `message_id` and an empty filename. It automatically found the attachment, downloaded it, and returned:

- `success = true`
- filename `paragon-fiskalny-PARKING1788567115966.png`
- MIME type `image/png`
- size `14376`
- non-empty `content_base64`

The corresponding audit row finalized as `succeeded` with arguments containing `message_id` and `filename: null` and no public `attachment_id` argument.

## GitHub

Workflow: `MCP — GitHub Read File`

Status: active.

Input: repository-relative `path`.

Missing files normalize to `NOT_FOUND`; other provider failures use `UPSTREAM_ERROR`.

## PostgreSQL

Workflow: `MCP — PostgreSQL Recent Jobs`

Status: active.

Input: optional `limit`, default `10`, range `1..50`.

Workflow: `MCP — PostgreSQL Job Details`

Status: active.

Input: UUID `job_id`.

Zero-row results normalize to `NOT_FOUND`. Database failures normalize to `UPSTREAM_ERROR`.

## Acceptance tests

Production acceptance evidence and regression rules are documented in:

`docs/ACCEPTANCE_TESTS.md`

Provider/database error branches are not deliberately forced by breaking working production credentials or SQL.

## Repository export state

Current deployed workflow exports:

- `n8n/MCP_SERVER.json`
- `n8n/AUDIT_TOOL_CALL.json`
- `n8n/github/GET_GITHUB_FILE.json`
- `n8n/gmail/SEARCH_EMAILS.json`
- `n8n/gmail/GET_EMAIL_ATTACHMENT.json`
- `n8n/postgres/GET_RECENT_JOBS.json`
- `n8n/postgres/GET_JOB_DETAILS.json`

Audit migrations:

- `database/migrations/001_mcp_tool_audit.sql`
- `database/migrations/002_redact_existing_email_audit_queries.sql`

The exports reference n8n credentials by credential metadata only; no plaintext credential values are intentionally stored in the repository.

## Security state

- Gmail and GitHub credentials remain in n8n credential storage.
- PostgreSQL business-read tools use the read-only `mcp_read` credential.
- The centralized audit workflow uses the write-capable application PostgreSQL credential only for `mcp_tool_calls` writes.
- No write-capable business tool is exposed through MCP.
- Sensitive audit arguments are sanitized centrally.
- Gmail `attachmentId` remains an internal implementation detail and is not required from the user.

## Exact next milestone

Continue M2 with:

1. `search_drive_files`
2. `read_drive_file`
3. `get_calendar_events`
4. `find_free_time`
