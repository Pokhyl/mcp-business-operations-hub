# Acceptance Tests

Last verified: 2026-09-08.

This document records production acceptance evidence for the read-only MCP tool surface and the current gateway regression state.

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

| ID | Tool | Case | Expected result | Status |
| --- | --- | --- | --- | --- |
| GH-01 | `get_github_file` | Existing file | `success=true`, `meta.count=1` | PASS |
| GH-02 | `get_github_file` | Missing file | `NOT_FOUND` | PASS |
| RJ-01 | `get_recent_jobs` | Valid limit | success with requested rows | PASS |
| RJ-02 | `get_recent_jobs` | Invalid limit | `INVALID_INPUT` | PASS |
| JD-01 | `get_job_details` | Existing job | `success=true` | PASS |
| JD-02 | `get_job_details` | Invalid UUID | `INVALID_INPUT` | PASS |
| JD-03 | `get_job_details` | Valid UUID with no row | `NOT_FOUND` | PASS |
| GM-01 | `search_emails` | Valid Gmail search | normalized emails returned | PASS |
| GM-02 | `search_emails` | Invalid input | `INVALID_INPUT` | PASS |
| GM-03 | `search_emails` | Audit redaction | stored Gmail query is `[REDACTED]` | PASS |
| GA-01 | `get_email_attachment` | Automatic single attachment | filename/MIME/size/base64 without public `attachment_id` | PASS |
| GA-02 | `get_email_attachment` | Filename mismatch | `NOT_FOUND` plus safe available attachment metadata | PASS |
| DS-01 | `search_drive_files` | Valid query, limit 5 | five normalized Drive files | PASS |
| DS-02 | `search_drive_files` | Invalid limit 51 | `INVALID_INPUT` | PASS |
| DS-03 | `search_drive_files` | No matching files | `success=true`, `data=[]`, `count=0` | PASS |
| DS-04 | `search_drive_files` | Natural MCP client search | real Drive matches returned | PASS |
| DR-01 | `read_drive_file` | Google Sheet | CSV content returned | PASS |
| DR-02 | `read_drive_file` | PDF | extracted text returned | PASS |
| DR-03 | `read_drive_file` | TXT/Markdown | text returned | PASS |
| DR-04 | `read_drive_file` | Google Doc | exported text returned | PASS |
| DR-05 | `read_drive_file` | Google Slides | exported text returned | PASS |
| DR-06 | `read_drive_file` | Unsupported MOV | `UNSUPPORTED_FILE_TYPE` | PASS |
| DR-07 | `read_drive_file` | Empty/invalid file ID | `INVALID_INPUT` | PASS |
| DR-08 | `read_drive_file` | Nonexistent file ID | `NOT_FOUND` | PASS |
| DR-09 | Drive cross-tool chain | natural prompt -> search -> read -> client summary | MCP client selects a real match, reads it, and summarizes content without user-provided file ID | PASS |
| CE-01 | `get_calendar_events` | Invalid input | `INVALID_INPUT`, no audit/provider call | PASS |
| CE-02 | `get_calendar_events` | Valid primary window | normalized `success=true`; empty list allowed | PASS |
| CE-03 | `get_calendar_events` | Nonexistent calendar | provider 404 -> `NOT_FOUND` | PASS |
| CE-04 | `get_calendar_events` | Audit lifecycle | succeeded and failed rows finalize with duration | PASS |
| CE-05 | `get_calendar_events` | Natural week/month/year prompts | MCP client resolves time windows and returns source-accurate empty results | PASS |
| FF-01 | `find_free_time` | Published workflow state | `versionId == activeVersionId` | PASS |
| FF-02 | `find_free_time` | Natural 60-minute slot request | source-accurate free window returned | PASS |
| FF-03 | `find_free_time` | Audit lifecycle | succeeded row with non-null duration | PASS |
| GW-01 | MCP Server Calendar surface | both accepted Calendar tools simultaneously present | `get_calendar_events` and `find_free_time` both exposed | FAIL — recovery pending |

## Verified Gmail attachment evidence

The deployed `get_email_attachment` contract is:

```json
{
  "message_id": "string",
  "filename": "optional string"
}
```

Gmail `attachmentId` is an internal implementation detail and is not required from the caller.

A real Gmail message with one normal attachment was called with only the real `message_id` and an empty filename. The workflow recursively found the MIME attachment, discovered `body.attachmentId` internally, downloaded it, and returned a normalized success response with filename, MIME type, size, and non-empty base64 content.

A deliberately nonexistent filename hint against the same valid message returned `NOT_FOUND` plus safe available attachment metadata. The internal Gmail attachment ID was not exposed.

## Verified Google Drive search evidence

### DS-01 — normal search

Input:

```json
{
  "query": "2026",
  "limit": 5
}
```

Observed: five matching Google Drive files, normalized metadata, `meta.count=5`.

### DS-02 — invalid limit

Input limit `51` is rejected before provider access with `INVALID_INPUT`.

### DS-03 — no matches

A deliberately nonexistent search term returned:

```json
{
  "success": true,
  "data": [],
  "meta": {
    "tool": "search_drive_files",
    "count": 0
  }
}
```

### DS-04 — natural MCP client search

A natural prompt asking for files related to `TikTok Video Pipeline` returned real matching Google Drive files without requiring the user to know Drive query syntax or file IDs.

## Verified Google Drive read evidence

### DR-01 — Google Sheet

File: `TikTok Video Pipeline v2 - Topic Intake`.

Observed:

- MIME type `application/vnd.google-apps.spreadsheet`
- `content_format=text/csv`
- real CSV content
- `truncated=false`

### DR-02 — PDF

File: `WUW komunikacja_.pdf`.

Observed:

- MIME type `application/pdf`
- real extracted Polish text
- `content_format=text/plain`
- `truncated=false`

### DR-03 — regular text/Markdown

File: `daily-research-report-2026-07-24.md`.

Observed real text content and stable metadata envelope.

### DR-04 — Google Doc

File: `Test task Android Dev`.

Observed successful Google Docs export to plain text.

### DR-05 — Google Slides

File: `Презентация без названия`.

Observed successful Google Slides export to plain text with real slide content.

### DR-06 — unsupported binary

A real MOV file returned `UNSUPPORTED_FILE_TYPE`. The failure path completed `Audit failed` and preserved the normalized business error.

### DR-07 — invalid input

Empty `file_id` returns `INVALID_INPUT` before audit/provider access.

### DR-08 — nonexistent Drive file

A deliberately nonexistent file ID produced a real Google Drive HTTP 404.

On n8n `2.33.3`, the HTTP Request node incorrectly routed the 404 through the success output despite `On Error -> Continue (using error output)`. Production was backed up and upgraded to `2.37.10` rather than adding a workflow-specific workaround.

After the upgrade the 404 followed the intended error output and normalized to `NOT_FOUND`.

Status: PASS.

### DR-09 — natural cross-tool MCP acceptance

Natural user prompt through Claude:

```text
Найди файл TikTok Video Pipeline в моём Google Drive и скажи, что в нём.
```

Observed behavior:

1. `search_drive_files` found two matching Google Sheets.
2. The client selected the more recently modified match automatically.
3. `read_drive_file` read that file.
4. Claude summarized the real intake-sheet content.

No Drive query syntax or file ID was supplied by the user.

Status: PASS.

## Verified Google Calendar events evidence

Detailed evidence is stored in `docs/CALENDAR_ACCEPTANCE.md`.

### CE-01 — invalid input

Empty input returns `INVALID_INPUT` before audit/provider access.

Status: PASS.

### CE-02 — valid primary calendar window

Test input:

```json
{
  "start": "2026-09-01T00:00:00+02:00",
  "end": "2026-10-01T00:00:00+02:00",
  "calendar_id": "primary",
  "limit": 50
}
```

The Google Calendar API returned a valid `calendar#events` response. The tested calendar was empty, so the normalized result was `success=true`, `data=[]`, `count=0`.

Status: PASS.

### CE-03 — nonexistent calendar

A deliberately nonexistent calendar produced HTTP 404, which followed the HTTP Request error output and normalized to:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Google Calendar not found"
  },
  "meta": {
    "tool": "get_calendar_events",
    "count": 0
  }
}
```

Status: PASS.

### CE-04 — audit lifecycle

Database evidence contains succeeded and failed `get_calendar_events` rows with non-null duration values.

Status: PASS.

### CE-05 — natural-language acceptance

Through Claude, natural requests for the current week, a month, and a year all invoked `get_calendar_events`. Claude reported no events, and the user confirmed that the source primary calendar was actually empty.

Status: PASS.

## Verified Find Free Time evidence

Detailed evidence is stored in `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

### FF-01 — publication

`MCP — Find Free Time` (`dDiqHH9C5clOrYOX`) is active and published with:

```text
versionId:       efe02511-9b12-4274-9d1a-39e597d7fe3a
activeVersionId: efe02511-9b12-4274-9d1a-39e597d7fe3a
```

Status: PASS.

### FF-02 — natural-language slot search

Natural request through Claude:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

The client generated:

```text
start:            2026-09-09T09:00:00+02:00
end:              2026-09-09T18:00:00+02:00
duration_minutes: 60
calendar_id:      primary
```

The connected calendar was empty, so the workflow returned the entire 09:00–18:00 interval as available. Claude explained that any one-hour slot inside the interval could be used.

Status: PASS.

### FF-03 — audit lifecycle

Production audit evidence:

```text
tool_name:   find_free_time
status:      succeeded
duration_ms: 640
```

The stored sanitized arguments match the accepted request window and duration.

Status: PASS.

## Gateway regression — GW-01

After the successful `find_free_time` E2E, the current published `MCP — Server` was inspected directly.

Published version:

```text
workflow_id:       dSohghXnQp078EZm
version_id:        db01b624-5108-4998-8a53-fd12680c9d25
active_version_id: db01b624-5108-4998-8a53-fd12680c9d25
```

Observed tool surface:

```text
find_free_time
get_email_attachment
get_github_file
get_job_details
get_recent_jobs
read_drive_file
search_drive_files
search_emails
```

`get_calendar_events` is missing even though it previously passed full acceptance and its sub-workflow remains active.

Expected result for GW-01:

```text
Both get_calendar_events and find_free_time are present in the same published MCP Server version.
```

Current status: FAIL — recovery pending.

The accepted repository export `n8n/MCP_SERVER.json` intentionally remains unchanged because it preserves the last accepted `get_calendar_events` configuration needed for restoration.

Recovery instructions and exact accepted node configuration are documented in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

## Runtime upgrade acceptance

Production n8n was upgraded from `2.33.3` to `2.37.10` after a full backup.

Post-upgrade checks:

- container version `2.37.10`
- database migrations completed
- n8n `/healthz` returned OK
- public endpoint returned HTTP 200
- existing executions continued successfully
- Google Drive 404 routing regression passed

## Provider/database failure policy

Provider/database failures normalize to `UPSTREAM_ERROR` unless a more specific stable application error is defined, such as `NOT_FOUND` or `UNSUPPORTED_FILE_TYPE`.

Working production credentials, SQL, or provider configuration must not be deliberately corrupted solely to manufacture provider failure tests.

## Regression rule for future changes

A current MCP tool is not accepted after a change until its applicable safe regression cases are rerun.

At minimum:

- validation stays before provider access;
- normalized envelopes remain stable unless intentionally versioned;
- one valid provider call creates and finalizes one audit row;
- audit integration does not replace the business response;
- Gmail search still applies its real provider query while audit storage redacts it;
- Gmail attachment retrieval never requires a user-supplied Gmail `attachmentId`;
- Drive uses the dedicated read-only OAuth credential;
- Drive search no-match remains a successful empty result;
- Drive read preserves explicit truncation metadata;
- Drive missing files normalize to `NOT_FOUND`;
- unsupported Drive binary types normalize to `UNSUPPORTED_FILE_TYPE`;
- Calendar read tools use the dedicated `calendar.readonly` credential;
- FreeBusy per-calendar errors are not treated as successful free-time responses;
- adding one MCP Server tool must not remove previously accepted tool nodes;
- after any MCP Server edit, the complete expected tool surface must be verified before milestone closure;
- working production credentials or SQL are not deliberately broken to force error tests.
