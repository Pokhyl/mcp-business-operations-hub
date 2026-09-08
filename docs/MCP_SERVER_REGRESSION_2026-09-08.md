# MCP Server Calendar Regression — 2026-09-08

## Summary

During post-acceptance documentation for `find_free_time`, the published production `MCP — Server` was inspected directly in the n8n PostgreSQL state.

The server is active and its current published version is:

```text
workflow: MCP — Server
workflow_id: dSohghXnQp078EZm
active: true
version_id: db01b624-5108-4998-8a53-fd12680c9d25
active_version_id: db01b624-5108-4998-8a53-fd12680c9d25
```

The currently published tool nodes are:

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

The previously accepted `get_calendar_events` tool node is missing.

## Prior accepted state

`get_calendar_events` had already passed:

- low-level success acceptance;
- `INVALID_INPUT` validation;
- provider 404 -> `NOT_FOUND` normalization;
- succeeded and failed audit finalization;
- natural-language MCP client acceptance for week, month, and year queries.

The accepted MCP Server export in `n8n/MCP_SERVER.json` still contains the correctly configured `get_calendar_events` node and therefore serves as recovery evidence.

## Current effect

`find_free_time` itself is working and passed a real natural-language E2E on 2026-09-08.

However, the aggregate MCP gateway surface regressed because adding/publishing `find_free_time` left the current production MCP Server without `get_calendar_events`.

This means M2 cannot be declared complete yet even though both Calendar sub-workflows individually have accepted behavior.

## Required recovery

Restore the existing `get_calendar_events` tool node in `MCP — Server` with the previously accepted configuration:

```text
Tool name: get_calendar_events
Workflow: MCP — Calendar Events
Workflow ID: IUpcFPRH3xOVbgEq
```

Description:

```text
Get events from the connected Google Calendar within a specific time window. Use this when the user asks about their schedule, meetings, appointments, or calendar events. start and end must be RFC3339 timestamps with timezone. Use calendar_id "primary" unless the user specifies another calendar.
```

Model-defined inputs:

```text
start
RFC3339 start of the requested time window, including timezone.

end
RFC3339 end of the requested time window, including timezone.

calendar_id
Google Calendar ID. Use "primary" unless the user explicitly requests another calendar.

limit
Maximum number of events to return. Use 50 unless a different limit is needed.
```

After restoration:

1. publish `MCP — Server`;
2. verify both `get_calendar_events` and `find_free_time` are present in the published tool surface;
3. rerun one natural-language `get_calendar_events` request;
4. rerun one natural-language `find_free_time` request;
5. only then update `n8n/MCP_SERVER.json` from the final published production state and mark M2 complete.

## Repository safety decision

The existing `n8n/MCP_SERVER.json` was intentionally not overwritten with the regressed production state. It preserves the last accepted `get_calendar_events` configuration needed for recovery.
