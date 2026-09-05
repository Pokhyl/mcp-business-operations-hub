# Acceptance Tests

Last verified: 2026-09-05.

This document records production acceptance evidence for the deployed read-only MCP tool surface.

Current tools:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`
- `get_email_attachment`

## Common contract

### Success envelope

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

### Error envelope

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

### Audit expectations

For valid inputs that reach a provider/database operation:

1. `Audit start` creates exactly one `mcp_tool_calls` row.
2. The same row is finalized as `succeeded` or `failed`.
3. `duration_ms` is populated on completion.
4. The tool returns the original normalized business response, not the audit sub-workflow response.
5. Sensitive arguments are sanitized before storage.

`INVALID_INPUT` is rejected before `Audit start`, so validation failures do not create audit rows.

## Test matrix

| ID | Tool | Case | Input | Expected result | Audit expectation | Status |
| --- | --- | --- | --- | --- | --- | --- |
| GH-01 | `get_github_file` | Existing file | `{"path":"docs/CURRENT_STATE.md"}` | `success=true`, `meta.count=1` | finalized `succeeded` row | PASS |
| GH-02 | `get_github_file` | Missing file | `{"path":"docs/THIS_FILE_DOES_NOT_EXIST.md"}` | `success=false`, `error.code=NOT_FOUND` | finalized `failed`, `error_code=NOT_FOUND` | PASS |
| RJ-01 | `get_recent_jobs` | Valid limit | `{"limit":5}` | `success=true`, five rows | finalized `succeeded` row | PASS |
| RJ-02 | `get_recent_jobs` | Invalid limit | `{"limit":100}` | `INVALID_INPUT` | no audit row | PASS |
| JD-01 | `get_job_details` | Existing job | `{"job_id":"4372be34-c417-415f-92f6-63481b3b5686"}` | `success=true`, matching job id | finalized `succeeded` row | PASS |
| JD-02 | `get_job_details` | Invalid UUID | invalid UUID string | `INVALID_INPUT` | no audit row | PASS |
| JD-03 | `get_job_details` | Valid UUID with no row | `{"job_id":"00000000-0000-4000-8000-000000000000"}` | `NOT_FOUND` | finalized `failed`, `error_code=NOT_FOUND` | PASS |
| GM-01 | `search_emails` | Valid Gmail search | `{"query":"newer_than:7d","limit":5}` | `success=true`, five normalized emails | finalized `succeeded` row | PASS |
| GM-02 | `search_emails` | Invalid input | empty query and/or invalid limit | `INVALID_INPUT` | no audit row | PASS |
| GM-03 | `search_emails` | Audit redaction | valid Gmail search | normal success preserved | stored query is `[REDACTED]` | PASS |
| GA-01 | `get_email_attachment` | Automatic single attachment | valid `message_id`, `filename=""` | `success=true`, filename/MIME/size/base64 returned without public `attachment_id` | finalized `succeeded` row with `message_id` and `filename:null` | PASS |
| GA-02 | `get_email_attachment` | Filename mismatch | valid `message_id`, nonexistent filename | `success=false`, `error.code=NOT_FOUND`, available attachment metadata returned | finalized `failed`, `error_code=NOT_FOUND` | PASS |

## Verified Gmail attachment evidence

The deployed `get_email_attachment` contract is:

```json
{
  "message_id": "string",
  "filename": "optional string"
}
```

Gmail `attachmentId` is an internal implementation detail and is not required from the caller.

### GA-01 — automatic selection and download

A real Gmail message with one normal attachment was used. The workflow was called with the real `message_id` and an empty filename.

Observed result:

```json
{
  "success": true,
  "data": {
    "filename": "paragon-fiskalny-PARKING1788567115966.png",
    "mime_type": "image/png",
    "size": 14376,
    "content_base64": "<non-empty base64>"
  },
  "meta": {
    "tool": "get_email_attachment",
    "count": 1
  }
}
```

The workflow recursively discovered the Gmail MIME attachment part, used the internal `body.attachmentId` to download it, and did not expose that ID in the public success response.

The latest corresponding audit row was verified as:

```text
get_email_attachment | succeeded | duration_ms=765 | {"filename": null, "message_id": "1a06ee890111f46f"}
```

### GA-02 — safe filename mismatch

The same valid message was called with a deliberately nonexistent filename hint.

Observed normalized result:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "No matching attachment found in message"
  },
  "data": {
    "available_attachments": [
      {
        "filename": "paragon-fiskalny-PARKING1788567115966.png",
        "mime_type": "image/png",
        "size": 14376
      }
    ]
  },
  "meta": {
    "tool": "get_email_attachment",
    "count": 0
  }
}
```

This confirms the tool can expose safe attachment metadata for retry without exposing Gmail attachment IDs.

`AMBIGUOUS_ATTACHMENT` is wired for messages with multiple candidate attachments. It returns available filenames for a retry with `filename`; this branch was not fabricated by altering a real mailbox message solely for testing.

## Existing production evidence

### `get_github_file`

Existing-file and safe missing-file cases are verified. Missing files normalize to `NOT_FOUND` and finalize the same audit row as failed.

### `get_recent_jobs`

Success with `limit:5` returns five rows. Invalid `limit:100` is rejected before audit.

### `get_job_details`

Success is verified for job `4372be34-c417-415f-92f6-63481b3b5686`. A valid UUID with no row returns `NOT_FOUND`; invalid UUIDs are rejected before PostgreSQL.

### `search_emails`

Success is verified with `{"query":"newer_than:7d","limit":5}`. The provider receives the real Gmail query through `filters.q`, while the audit copy stores `query: [REDACTED]`.

## Provider/database failure branches

Provider/database failures normalize to `UPSTREAM_ERROR`:

- Gmail API/node errors -> `Gmail request failed`
- PostgreSQL errors -> `Database request failed`
- non-`NOT_FOUND` GitHub errors -> `UPSTREAM_ERROR`

These branches must not be tested by deliberately corrupting working production credentials, SQL, or provider configuration.

## Historical audit cleanup

Migration `database/migrations/002_redact_existing_email_audit_queries.sql` was applied to historical `search_emails` audit rows. A post-migration check found zero remaining unredacted Gmail query values.

## Regression rule for future changes

A current MCP tool is not accepted after a change until its applicable safe regression cases are rerun.

At minimum:

- validation stays before provider access;
- normalized envelopes remain stable unless intentionally versioned;
- one valid provider call creates and finalizes one audit row;
- audit integration does not replace the business response;
- Gmail search still applies `filters.q`;
- Gmail attachment retrieval never requires a user-supplied Gmail `attachmentId`;
- sensitive audit values remain redacted;
- working production credentials or SQL are not deliberately broken to force error tests.
