# Acceptance Tests

Last verified: 2026-09-06.

This document records production acceptance evidence for the deployed read-only MCP tool surface.

Current tools:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`
- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`

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
| DR-09 | Drive cross-tool chain | natural prompt -> search -> read -> client summary | pending final rerun after latest publish | PENDING |

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

A real MOV file returned:

```json
{
  "success": false,
  "error": {
    "code": "UNSUPPORTED_FILE_TYPE",
    "message": "This Google Drive file type is not supported for text extraction"
  },
  "meta": {
    "tool": "read_drive_file",
    "count": 0
  }
}
```

The failure path completed `Audit failed` and preserved the normalized business error.

### DR-07 — invalid input

Empty `file_id` returns `INVALID_INPUT` before audit/provider access.

### DR-08 — nonexistent Drive file

Test input:

```text
1_THIS_FILE_DOES_NOT_EXIST_987654321
```

On n8n `2.33.3`, the Google Drive metadata request produced a real HTTP 404 object containing `details.httpCode="404"`, but `HTTP Request` incorrectly sent that item through the success output despite `On Error -> Continue (using error output)`. That caused downstream file-type fallback and initially misclassified the missing file as an unsupported type.

This was treated as a runtime defect, not patched with an extra workflow-specific IF. Production was backed up and n8n was upgraded to `2.37.10`.

After the upgrade the same 404 correctly followed:

```text
Get file metadata
 -> Error output
 -> Format Drive error
 -> Preserve MCP error
 -> Audit failed
 -> Return MCP error
```

`Format Drive error` reads the actual provider status from `details.httpCode` and normalizes 404 to:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Google Drive file not found"
  },
  "meta": {
    "tool": "read_drive_file",
    "count": 0
  }
}
```

Status: PASS.

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
- working production credentials or SQL are not deliberately broken to force error tests.
