# Acceptance Tests

Last verified: 2026-09-05.

This document is the acceptance-test record for the currently deployed read-only MCP tool surface.

Current tools:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`

The purpose is to record actual production behavior and the exact regression checks that must remain true after future changes. It does not claim that destructive provider failures were induced when doing so would require breaking a working credential or database path.

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
4. The tool still returns the original normalized MCP response, not the audit sub-workflow response.
5. Sensitive arguments are sanitized before storage.

Current design intentionally rejects `INVALID_INPUT` before `Audit start`, so validation failures do not create audit rows.

## Test matrix

| ID | Tool | Case | Input | Expected result | Audit expectation | Status |
| --- | --- | --- | --- | --- | --- | --- |
| GH-01 | `get_github_file` | Existing file | `{"path":"docs/CURRENT_STATE.md"}` | `success=true`, `meta.tool=get_github_file`, `meta.count=1` | one finalized `succeeded` row with repository path | PASS |
| GH-02 | `get_github_file` | Missing file | `{"path":"docs/THIS_FILE_DOES_NOT_EXIST.md"}` | `success=false`, `error.code=NOT_FOUND`, `meta.count=0` | same audit row finalized `failed`, `error_code=NOT_FOUND` | PASS |
| RJ-01 | `get_recent_jobs` | Valid limit | `{"limit":5}` | `success=true`, five rows returned, `meta.tool=get_recent_jobs`, `meta.count=5` | finalized `succeeded` row with `{"limit":5}` | PASS |
| RJ-02 | `get_recent_jobs` | Invalid limit | `{"limit":100}` | `success=false`, `error.code=INVALID_INPUT`, message states integer range `1..50` | no audit row because validation fails before audit | PASS |
| JD-01 | `get_job_details` | Existing job | `{"job_id":"4372be34-c417-415f-92f6-63481b3b5686"}` | `success=true`, returned job id matches input, `meta.count=1` | finalized `succeeded` row with the job UUID | PASS |
| JD-02 | `get_job_details` | Invalid UUID | invalid UUID string | `success=false`, `error.code=INVALID_INPUT`, message `job_id must be a valid UUID` | no audit row because validation fails before audit | PASS |
| JD-03 | `get_job_details` | Valid UUID with no row | `{"job_id":"00000000-0000-4000-8000-000000000000"}` | `success=false`, `error.code=NOT_FOUND`, message `Job not found` | same audit row finalized `failed`, `error_code=NOT_FOUND` | PASS |
| GM-01 | `search_emails` | Valid Gmail search | `{"query":"newer_than:7d","limit":5}` | `success=true`, `meta.tool=search_emails`, `meta.count=5`; each item contains normalized mail fields | finalized `succeeded` row | PASS |
| GM-02 | `search_emails` | Invalid input | empty query and/or limit outside `1..50` | `success=false`, `error.code=INVALID_INPUT` | no audit row because validation fails before audit | PASS |
| GM-03 | `search_emails` | Audit redaction | valid Gmail search | normal success response is preserved | stored `arguments_json.query` is `[REDACTED]` while `limit` remains visible | PASS |

## Verified production evidence

### `get_github_file`

Success was rerun against:

```json
{
  "path": "docs/CURRENT_STATE.md"
}
```

A real missing-file request was rerun against:

```json
{
  "path": "docs/THIS_FILE_DOES_NOT_EXIST.md"
}
```

The upstream GitHub message was:

```text
The resource you are requesting could not be found
```

The normalized MCP result was:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "The resource you are requesting could not be found"
  },
  "meta": {
    "tool": "get_github_file",
    "count": 0
  }
}
```

The corresponding audit row finalized as `failed` with `error_code = NOT_FOUND`.

### `get_recent_jobs`

Production success regression was rerun with:

```json
{
  "limit": 5
}
```

The final MCP response still contained five jobs and:

```json
{
  "tool": "get_recent_jobs",
  "count": 5
}
```

The corresponding audit row finalized as `succeeded` with:

```json
{
  "limit": 5
}
```

The invalid-limit contract was previously verified with `limit: 100` and remains before `Audit start` in the deployed flow.

### `get_job_details`

Success regression was rerun with:

```json
{
  "job_id": "4372be34-c417-415f-92f6-63481b3b5686"
}
```

The response returned the same id with `success=true` and `meta.count=1`, and the audit row finalized as `succeeded`.

The safe `NOT_FOUND` case was rerun with:

```json
{
  "job_id": "00000000-0000-4000-8000-000000000000"
}
```

The final result was:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Job not found"
  },
  "meta": {
    "tool": "get_job_details",
    "count": 0
  }
}
```

The same audit row finalized as `failed` with `error_code = NOT_FOUND`.

Invalid UUID validation was verified before PostgreSQL and returns `INVALID_INPUT` without creating an audit row.

### `search_emails`

Production success regression was rerun with:

```json
{
  "query": "newer_than:7d",
  "limit": 5
}
```

The tool returned five normalized messages with the success envelope intact.

After centralized redaction was deployed, the corresponding audit row stored:

```json
{
  "limit": 5,
  "query": "[REDACTED]"
}
```

The Gmail query still reaches the Gmail node through `filters.q`; redaction applies only to the audit copy and does not alter the provider request.

Invalid input remains rejected before Gmail and before audit with `INVALID_INPUT`.

## Provider/database failure branches

The deployed workflows also normalize provider/database failures to `UPSTREAM_ERROR`:

- Gmail node errors -> `Gmail request failed`
- PostgreSQL errors in `get_recent_jobs` -> `Database request failed`
- PostgreSQL errors in `get_job_details` -> `Database request failed`
- non-`NOT_FOUND` GitHub errors -> `UPSTREAM_ERROR`

These branches are wired to `Audit failed` for valid audited calls. They must not be tested by deliberately corrupting production credentials, SQL, or provider configuration merely to force an error. A real provider failure, credential rotation, or maintenance event should be used as the next non-destructive opportunity to re-verify these branches.

## Historical audit cleanup

Migration:

`database/migrations/002_redact_existing_email_audit_queries.sql`

was applied to historical `search_emails` audit rows. It updated two existing raw Gmail-query values. A post-migration query found zero remaining unredacted `search_emails.query` values.

## Regression rule for future changes

A change to any current MCP tool is not accepted until its applicable rows in this matrix are rerun.

At minimum:

- input validation must remain before provider access;
- normalized MCP envelopes must remain unchanged unless the contract is intentionally versioned;
- one valid call must create and finalize one audit row;
- audit integration must not replace or corrupt the returned business response;
- Gmail search must still apply the requested query through `filters.q`;
- sensitive audit values must remain redacted;
- working success paths must not be deliberately broken just to test an error branch.
