# MCP Tools

Production acceptance cases and regression rules for the current tool surface are documented in `docs/ACCEPTANCE_TESTS.md`.

## `search_emails`

Purpose: search Gmail and return full normalized message content for matching emails.

Inputs:

```json
{
  "query": "string",
  "limit": 5
}
```

Output per message includes `id`, `threadId`, `from`, `to`, `subject`, `date`, and `body`.

Access: read-only.

Audit note: the Gmail query is used for the provider request but stored as `[REDACTED]` in audit `arguments_json`.

## `get_email_attachment`

Purpose: retrieve an attachment from a Gmail message without requiring the caller or user to know Gmail's internal `attachmentId`.

Inputs:

```json
{
  "message_id": "string",
  "filename": "optional string"
}
```

`message_id` is normally obtained internally from `search_emails`.

`filename` is optional. When the message has exactly one normal attachment, the tool selects it automatically. If multiple attachments exist, the tool returns safe attachment metadata so the agent can retry with an exact or partial `filename`.

Successful output contains filename, MIME type, size, and `content_base64`. The internal Gmail `attachmentId` is never part of the public contract.

Possible normalized selection errors include `NOT_FOUND` and `AMBIGUOUS_ATTACHMENT`. Gmail API failures use `UPSTREAM_ERROR`.

Access: read-only.

## `search_drive_files`

Purpose: search the connected Google Drive by filename or full-text content.

Inputs:

```json
{
  "query": "string",
  "limit": 10
}
```

Rules:

- `query` must be a non-empty natural search term.
- `limit` defaults to `10` and must be an integer from `1` to `50`.
- callers do not provide raw Google Drive query syntax; the workflow builds it internally.
- trashed files are excluded.

Successful output contains an array of normalized file metadata:

```json
{
  "success": true,
  "data": [
    {
      "id": "drive-file-id",
      "name": "example.pdf",
      "mime_type": "application/pdf",
      "modified_time": "2026-09-06T10:00:00.000Z",
      "size": 12345,
      "web_view_link": "...",
      "parents": ["..."],
      "drive_id": null
    }
  ],
  "meta": {
    "tool": "search_drive_files",
    "count": 1
  }
}
```

No matches are a successful empty result: `success=true`, `data=[]`, `count=0`.

Invalid input uses `INVALID_INPUT`. Google Drive provider failures use `UPSTREAM_ERROR`.

Access: read-only through a dedicated OAuth credential with `https://www.googleapis.com/auth/drive.readonly`.

## `read_drive_file`

Purpose: read the textual contents of a Google Drive file by `file_id`, normally after `search_drive_files` finds the file.

Input:

```json
{
  "file_id": "string"
}
```

Supported types:

- Google Docs -> exported to `text/plain`
- Google Sheets -> exported to `text/csv`
- Google Slides -> exported to `text/plain`
- PDF -> downloaded and text extracted
- text-based files -> downloaded as text

Successful output:

```json
{
  "success": true,
  "data": {
    "file_id": "...",
    "name": "...",
    "mime_type": "...",
    "modified_time": "...",
    "size": 12345,
    "web_view_link": "...",
    "content_format": "text/plain",
    "content": "...",
    "truncated": false,
    "original_content_length": 1234
  },
  "meta": {
    "tool": "read_drive_file",
    "count": 1
  }
}
```

Text is capped at `50000` characters. Truncation is explicitly reported through `truncated` and `original_content_length`.

Errors:

- empty `file_id` -> `INVALID_INPUT`
- missing Drive file / provider 404 -> `NOT_FOUND`
- unsupported binary type -> `UNSUPPORTED_FILE_TYPE`
- other Google Drive failures -> `UPSTREAM_ERROR`

Access: read-only through the dedicated Google Drive OAuth credential.

## `get_github_file`

Purpose: read a text file from the configured GitHub repository.

Input:

```json
{
  "path": "docs/CURRENT_STATE.md"
}
```

Access: read-only.

## `get_recent_jobs`

Purpose: inspect recent production content jobs.

Input:

```json
{
  "limit": 10
}
```

Access: read-only PostgreSQL query.

## `get_job_details`

Purpose: inspect one content job in detail.

Input:

```json
{
  "job_id": "uuid"
}
```

Returned fields include status, current stage, last error, review fields, and timestamps.

Access: read-only PostgreSQL query.

## `get_calendar_events`

Workflow: `MCP — Calendar Events` (`IUpcFPRH3xOVbgEq`).

Purpose: read Google Calendar events for an explicit time window.

Inputs:

```json
{
  "start": "2026-09-01T00:00:00+02:00",
  "end": "2026-10-01T00:00:00+02:00",
  "calendar_id": "primary",
  "limit": 50
}
```

Rules:

- `start` and `end` must be RFC3339 timestamps with timezone.
- `end` must be later than `start`.
- `calendar_id` defaults to `primary`.
- `limit` defaults to `50` and must be an integer from `1` to `2500`.
- recurring events are expanded with `singleEvents=true` and sorted with `orderBy=startTime`.

Successful output normalizes event ID, status, summary, description, location, timed/all-day start and end values, organizer, attendees, HTML link, and recurring-event ID.

Errors:

- invalid input -> `INVALID_INPUT`
- missing/nonexistent calendar (provider HTTP 404) -> `NOT_FOUND`
- other Calendar API failures -> `UPSTREAM_ERROR`

Access: read-only through dedicated `Google Calendar MCP readonly` OAuth credential with `https://www.googleapis.com/auth/calendar.readonly`.

Acceptance: low-level success/error/audit tests and natural-language MCP client tests are complete. Natural-language checks covered current week, month, and year windows.

Current gateway note: during the 2026-09-08 `find_free_time` rollout, the currently published `MCP — Server` lost this already accepted tool node. The sub-workflow remains active and accepted. Recovery is tracked in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

## `find_free_time`

Workflow: `MCP — Find Free Time` (`dDiqHH9C5clOrYOX`).

Purpose: return maximal free windows in Google Calendar that can fit a requested minimum duration.

Inputs:

```json
{
  "start": "2026-09-09T09:00:00+02:00",
  "end": "2026-09-09T18:00:00+02:00",
  "duration_minutes": 60,
  "calendar_id": "primary"
}
```

Rules:

- `start` and `end` must be RFC3339 timestamps with timezone.
- `end` must be later than `start`.
- `duration_minutes` defaults to `30`, must be a positive integer, and must fit inside the requested range.
- `calendar_id` defaults to `primary`.
- the workflow uses Google Calendar `freeBusy.query`, not full event retrieval.
- provider-level calendar errors returned inside an HTTP 200 FreeBusy response are checked before computing windows.
- overlapping/touching busy intervals are merged before free windows are derived.
- only free windows at least `duration_minutes` long are returned.

Successful output:

```json
{
  "success": true,
  "data": [
    {
      "start": "2026-09-09T07:00:00.000Z",
      "end": "2026-09-09T16:00:00.000Z",
      "duration_minutes": 540
    }
  ],
  "meta": {
    "tool": "find_free_time",
    "count": 1,
    "calendar_id": "primary",
    "requested_duration_minutes": 60
  }
}
```

Errors:

- invalid input -> `INVALID_INPUT`
- missing/nonexistent calendar -> `NOT_FOUND`
- other Calendar FreeBusy failures -> `UPSTREAM_ERROR`

Access: read-only through the same dedicated `Google Calendar MCP readonly` OAuth credential.

Acceptance: published, exposed, and natural-language E2E accepted on 2026-09-08. The production audit row for the accepted call finalized as `succeeded` with `duration_ms=640`.

Detailed evidence: `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

## Planned tools

### CRM

- `search_customers(query, limit)`
- `get_customer_details(customer_id)`

### Write tools — separate approval class

- `send_email`
- `create_calendar_event`
- `update_customer`
