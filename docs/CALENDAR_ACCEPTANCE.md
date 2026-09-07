# Google Calendar Workflow Acceptance

Last verified: 2026-09-07.

Workflow: `MCP — Calendar Events`

Workflow ID: `IUpcFPRH3xOVbgEq`

Current state: published and active as a sub-workflow. It is not yet exposed through `MCP — Server`.

Credential: `Google Calendar MCP readonly`

OAuth scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

## Contract

Inputs:

```json
{
  "start": "RFC3339 timestamp with timezone",
  "end": "RFC3339 timestamp with timezone",
  "calendar_id": "optional string, default primary",
  "limit": "optional integer, default 50, range 1..2500"
}
```

Success envelope:

```json
{
  "success": true,
  "data": [],
  "meta": {
    "tool": "get_calendar_events",
    "count": 0,
    "calendar_id": "primary",
    "time_zone": "UTC"
  }
}
```

Errors use the standard MCP envelope with `INVALID_INPUT`, `NOT_FOUND`, or `UPSTREAM_ERROR`.

## Execution flow

```text
When Executed by Another Workflow
 -> Validate input
 -> Is input valid?
    -> false: Format invalid input error
    -> true: Audit start
             -> Get calendar events
                -> Success: Format calendar events
                            -> Audit success
                            -> Return MCP response
                -> Error: Format Calendar error
                          -> Audit failed
                          -> Return MCP error
```

`arguments_json` is supplied only on `Audit start`. Both `Audit success` and `Audit failed` omit it.

## CE-01 — invalid input

A CLI execution with no sub-workflow input followed the validation failure branch and returned:

```json
{
  "success": false,
  "error": {
    "code": "INVALID_INPUT",
    "message": "start and end must be valid date-times with end after start, calendar_id must be a string, and limit must be an integer between 1 and 2500"
  },
  "meta": {
    "tool": "get_calendar_events",
    "count": 0
  }
}
```

`Audit start` and Google Calendar were not executed.

Status: PASS.

## CE-02 — valid primary-calendar request

A production-credential smoke execution used:

```json
{
  "start": "2026-09-01T00:00:00+02:00",
  "end": "2026-10-01T00:00:00+02:00",
  "calendar_id": "primary",
  "limit": 50
}
```

Observed provider response:

- `kind=calendar#events`
- calendar summary matched the connected account
- `accessRole=owner`
- `timeZone=UTC`
- the tested window contained no events

Normalized business result:

```json
{
  "success": true,
  "data": [],
  "meta": {
    "tool": "get_calendar_events",
    "count": 0,
    "calendar_id": "primary",
    "time_zone": "UTC"
  }
}
```

The audit row finalized as `succeeded` with non-null `duration_ms` and `completed_at`.

Status: PASS.

## CE-03 — nonexistent calendar

Test calendar ID:

```text
this-calendar-does-not-exist-987654321
```

The real n8n HTTP Request error object contained:

```json
{
  "details": {
    "description": "Not Found",
    "httpCode": "404"
  }
}
```

The request correctly used the HTTP Request Error output on n8n `2.37.10`.

Observed path:

```text
Get calendar events
 -> Error output
 -> Format Calendar error
 -> Audit failed
 -> Return MCP error
```

Final normalized result:

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

The normalizer reads the stable numeric HTTP status from `details.httpCode`; it does not parse human-readable provider text.

The audit row finalized as `failed` with `error_code=NOT_FOUND`, non-null `duration_ms`, and `completed_at`.

Status: PASS.

## CE-04 — audit database evidence

Verified `mcp_tool_calls` rows:

- one `get_calendar_events` row finalized as `succeeded`
- one `get_calendar_events` row finalized as `failed` with `error_code=NOT_FOUND`
- both rows have populated duration and completion timestamps
- `arguments_json` contains the requested time range, calendar ID, and limit

Status: PASS.

## Temporary smoke workflow cleanup

The low-level success/error tests were executed through a temporary manual-trigger clone so the production sub-workflow did not need test-only trigger changes. After testing, the temporary workflow was deactivated and archived.

## Remaining acceptance

The workflow itself is low-level accepted. Remaining work for the `get_calendar_events` roadmap item:

1. expose it through `MCP — Server`;
2. publish the updated MCP server;
3. run a natural-language MCP client test without user-supplied calendar IDs or structured API parameters.
