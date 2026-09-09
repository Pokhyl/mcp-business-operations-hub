# MCP Tools

Production acceptance cases and regression rules for the current tool surface are documented in `docs/ACCEPTANCE_TESTS.md`. KeyCRM M3 evidence is in `docs/M3_KEYCRM_ACCEPTANCE.md`.

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

Text is capped at `50000` characters. Truncation is explicitly reported.

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

Errors:

- invalid input -> `INVALID_INPUT`
- missing/nonexistent calendar -> `NOT_FOUND`
- other Calendar API failures -> `UPSTREAM_ERROR`

Access: read-only through dedicated `Google Calendar MCP readonly` OAuth credential with `https://www.googleapis.com/auth/calendar.readonly`.

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

The workflow uses Google Calendar FreeBusy, validates provider-level calendar errors, merges busy intervals, and returns only qualifying free windows.

Access: read-only through the same dedicated Calendar OAuth credential.

## `search_customers`

Workflow: `MCP — KeyCRM Customer Search` (`yej0SNKc4Ovb4rzq`).

Purpose: identify KeyCRM customers from natural customer identifiers without scanning the entire CRM on every request.

Inputs:

```json
{
  "query": "string",
  "limit": 10
}
```

Rules:

- `query` must be a non-empty string.
- `limit` defaults to `10` and must be an integer from `1` to `50`.
- query may be a full/partial name, email, phone number, or buyer ID.
- search runs against the synchronized minimal PostgreSQL customer index, not directly across all KeyCRM pages.
- KeyCRM remains the source of truth.

Successful output:

```json
{
  "success": true,
  "data": [
    {
      "buyer_id": 12345,
      "full_name": "Example Customer",
      "phones": ["..."],
      "emails": ["..."],
      "keycrm_updated_at": "2026-09-09T10:00:00.000Z"
    }
  ],
  "meta": {
    "tool": "search_customers",
    "count": 1
  }
}
```

Name matching ranks exact, prefix, substring, and trigram-similar results. Email and phone matching are normalized inside PostgreSQL.

Access: read-only through n8n credential `mcp_read`, backed by PostgreSQL role `mcp_readonly`.

Verified database permissions on `public.keycrm_customers`:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

Audit note: the actual customer query is stored as `[REDACTED]` because it may contain PII.

Errors:

- invalid input -> `INVALID_INPUT`
- database/provider failure -> `UPSTREAM_ERROR`

No matches are a successful empty result.

## `get_customer_details`

Workflow: `MCP — KeyCRM Customer Details` (`KcrmDetA9V7cQ2Lx`).

Purpose: retrieve the current KeyCRM customer record after `search_customers` identifies a `buyer_id`.

Input:

```json
{
  "buyer_id": 12345
}
```

Rules:

- `buyer_id` must be a positive integer.
- the workflow performs a fresh `GET /buyer/{buyer_id}` request to KeyCRM.
- the local search index is not used as the full-details source.

Successful data includes current customer identity/contact fields plus CRM metadata such as birthday, note, order totals/count, discount, manager ID, and timestamps when present.

Errors:

- invalid buyer ID -> `INVALID_INPUT`
- nonexistent buyer / provider 404 -> `NOT_FOUND`
- other KeyCRM failures -> `UPSTREAM_ERROR`

Access: read-only KeyCRM GET request through the `KeyCRM MCP` Bearer credential.

## Internal CRM synchronization

The following workflows are infrastructure workflows, not MCP tools:

- `ADMIN — KeyCRM Customer Index Sync` — one-time full bootstrap
- `ADMIN — KeyCRM Customer Index Incremental Sync` — permanent 15-minute incremental synchronization

The permanent sync uses KeyCRM `filter[updated_between]`, pagination with a 4-second request interval, local UPSERT by `buyer_id`, and `public.keycrm_sync_state` as a successful checkpoint.

Detailed evidence: `docs/M3_KEYCRM_ACCEPTANCE.md`.

## Write tools — future separate approval class

- `send_email`
- `create_calendar_event`
- `update_customer`

No write-capable business tool is currently exposed through MCP.
