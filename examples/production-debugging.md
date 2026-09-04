# Example — Diagnose a failed production job

## Prompt

```text
Why did the latest content job fail?
```

## Expected tool behavior

1. Call `get_recent_jobs`.
2. Identify the most recent relevant failed job.
3. Call `get_job_details` with that job UUID.
4. Use `current_stage` and `last_error` as evidence.
5. Explain the failure without inventing missing runtime facts.

## What this demonstrates

- sequential MCP tool use
- database least-privilege access
- parameterized SQL
- AI reasoning over operational evidence
