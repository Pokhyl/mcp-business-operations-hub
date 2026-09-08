# Google Calendar Workflow Acceptance

Last verified: 2026-09-08.

Workflow: `MCP — Calendar Events`

Workflow ID: `IUpcFPRH3xOVbgEq`

Current state: published, active, exposed through `MCP — Server`, and accepted end to end through the MCP client.

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

A CLI execution with no sub-workflow input followed the validation failure branch and returned `INVALID_INPUT`. `Audit start` and Google Calendar were not executed.

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

Google Calendar returned a valid `calendar#events` response. The tested window contained no events, so the normalized business response was `success=true`, `data=[]`, `count=0`, and `calendar_id=primary`. The audit row finalized as `succeeded`.

Status: PASS.

## CE-03 — nonexistent calendar

A deliberately nonexistent calendar ID produced the real n8n provider error object with `details.httpCode="404"`.

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

The audit row finalized as `failed` with `error_code=NOT_FOUND`.

Status: PASS.

## CE-04 — audit lifecycle

Verified database evidence contains one succeeded and one failed `get_calendar_events` row, both with non-null `duration_ms` and completion timestamps.

Status: PASS.

## CE-05 — natural-language MCP client acceptance

`get_calendar_events` was exposed through `MCP — Server` with all four workflow inputs defined by the model:

- `start` — RFC3339 start of requested window
- `end` — RFC3339 end of requested window
- `calendar_id` — defaults to `primary`
- `limit` — defaults to `50`

Natural-language testing was then performed through Claude without supplying RFC3339 timestamps, calendar IDs, or other API parameters manually.

Observed requests and behavior:

1. The user asked what was in the calendar for the current week. Claude invoked `get_calendar_events` and reported no events for 7–13 September 2026.
2. The user then asked for a month. Claude invoked `get_calendar_events` again and reported no events for 8 September–8 October 2026.
3. The user then asked for a year. Claude invoked `get_calendar_events` again and reported that the primary calendar was empty for the requested year window.
4. The user confirmed that the calendar really contained no events, so the empty responses matched the source of truth rather than representing a false negative.

This verifies the intended production chain:

```text
natural user request
 -> MCP client resolves requested time window
 -> get_calendar_events(start, end, primary, limit)
 -> Google Calendar API
 -> normalized result
 -> client explanation
```

No structured API parameters were supplied by the user.

Status: PASS.

## Temporary smoke workflow cleanup

Low-level success/error tests used a temporary manual-trigger clone so the production sub-workflow did not need test-only trigger changes. The temporary workflow was deactivated and archived after testing.

## Final status

`get_calendar_events` is fully accepted for M2: low-level workflow behavior, normalized errors, audit lifecycle, MCP Server exposure, and natural-language client behavior are all verified.

Next M2 tool: `find_free_time`.
