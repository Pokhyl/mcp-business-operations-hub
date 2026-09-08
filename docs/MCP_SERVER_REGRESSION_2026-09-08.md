# MCP Server Calendar Regression — 2026-09-08

## Summary

During post-acceptance inspection for `find_free_time`, the published production `MCP — Server` was found to contain `find_free_time` but to have lost the previously accepted `get_calendar_events` tool node.

This was an aggregate MCP gateway regression, not a failure of either Calendar sub-workflow.

## Recovery status

The missing `get_calendar_events` tool node has been restored in `MCP — Server` with the previously accepted configuration and the server has been published again.

Current production MCP Server version:

```text
workflow: MCP — Server
workflow_id: dSohghXnQp078EZm
active: true
version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
active_version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
```

The published Calendar surface now contains both:

```text
get_calendar_events
find_free_time
```

Direct production inspection verified both tool nodes are connected to `MCP Server Trigger`.

## `get_calendar_events`

Workflow: `MCP — Calendar Events`

Workflow ID: `IUpcFPRH3xOVbgEq`

Previously accepted behavior remains documented in `docs/CALENDAR_ACCEPTANCE.md`, including low-level success, `INVALID_INPUT`, provider 404 -> `NOT_FOUND`, audit finalization, and natural-language week/month/year queries.

## `find_free_time`

Workflow: `MCP — Find Free Time`

Workflow ID: `dDiqHH9C5clOrYOX`

The tool passed a real natural-language E2E on 2026-09-08 for a 60-minute slot between 09:00 and 18:00. The corresponding `mcp_tool_calls` audit row finalized as `succeeded`.

## Repository synchronization

`n8n/MCP_SERVER.json` has now been synchronized with the recovered published production surface. The export contains both Calendar tools and references the current published MCP Server version.

## Remaining regression check

The production structure is recovered and the repository is synchronized.

For strict post-recovery regression closure, rerun one natural-language request for each Calendar tool against the recovered MCP Server:

1. `get_calendar_events`
2. `find_free_time`

After both pass on the recovered aggregate surface, this regression can be considered fully closed and M2 can be marked complete without qualification.
