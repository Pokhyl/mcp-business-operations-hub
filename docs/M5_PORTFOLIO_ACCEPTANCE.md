# M5 Portfolio Hardening Acceptance

Last verified: 2026-09-10.

## Scope

M5 prepares the existing production MCP project for recruiter/interview review without changing production business behavior.

Production MCP workflows were not modified during this M5 pass.

## Recruiter-facing README — PASS

`README.md` was rewritten from the stale M2-era version to the actual current state.

Verified content now includes:

```text
17 read-only MCP tools
Gmail
Google Drive
Google Calendar
GitHub
PostgreSQL
KeyCRM
n8n 2.37.10
M0-M3 complete
M4 deferred
M5 in progress
```

The README explains architecture, tool groups, business use cases, read-only/security boundaries, local KeyCRM read models, audit flow, provider limitations, production defects found during acceptance, and engineering principles.

## Portfolio architecture — PASS

Created:

```text
docs/PORTFOLIO_ARCHITECTURE.md
```

The document contains a GitHub-rendered Mermaid diagram showing:

```text
AI/MCP client
-> OAuth2-protected n8n MCP gateway
-> isolated provider workflows
-> Gmail / Drive / Calendar / GitHub / KeyCRM APIs
-> PostgreSQL job reads and local CRM indexes
-> internal KeyCRM synchronization
-> centralized audit workflow
-> n8n credential storage boundary
```

The diagram is intentionally recruiter-level while `docs/ARCHITECTURE.md` remains the detailed engineering reference.

## Sanitized examples — PASS

Created:

```text
examples/README.md
```

Coverage:

```text
Gmail lookup
Drive search + read
Calendar availability
production job diagnosis
KeyCRM customer lookup
manager analytics
manager call timeline
provider limitation handling
```

Rules applied:

- no real mailbox content;
- no real customer PII;
- no credentials/tokens;
- no real confidential business metrics in public demo payloads;
- synthetic values are explicitly labeled synthetic rather than represented as production results.

## Automated n8n export validation — PASS

Created:

```text
scripts/validate_n8n_exports.py
.github/workflows/validate-n8n-exports.yml
```

The validator checks all committed `n8n/**/*.json` files for:

- valid JSON;
- valid workflow root shape;
- non-empty workflow export arrays;
- workflow names;
- nodes/connections structure;
- node names and node types;
- duplicate node names/IDs;
- connection references to existing nodes.

CI trigger:

```text
push
pull_request
```

for relevant workflow/validator paths.

First real GitHub Actions execution:

```text
workflow:   Validate n8n exports
run:        #1
run_id:     34445428630
event:      push
conclusion: success
commit:     c48d2e38b31eba181be553b834a7ffd6e20cc896
```

Therefore automated export validation is accepted as operational, not merely committed code.

## Deployment/operations runbook — PASS

Created:

```text
docs/RUNBOOK.md
```

The runbook records:

- GitHub source-of-truth rule;
- production health boundary;
- documentation/workflow/database change classes;
- production release sequence;
- gateway full-tool-surface verification;
- audit acceptance rules;
- provider/data reconciliation requirements;
- synchronization checkpoint rules;
- normalized error handling;
- local and CI workflow-export validation;
- runtime-upgrade procedure;
- KeyCRM provider boundaries;
- M4 deferral;
- rollback procedure;
- release completion checklist.

## Demo video/GIF preparation — READY, RECORDING NOT YET COMPLETE

Created recording plan:

```text
docs/DEMO_VIDEO_SCRIPT.md
```

The recommended demo uses a safe real MCP call against the public project repository and avoids showing Gmail, Calendar, CRM PII, credentials, or confidential metrics.

Target length:

```text
45-75 seconds
```

The actual video/GIF roadmap item remains incomplete until a real recording exists and is reviewed for sensitive data.

## M5 status

```text
Recruiter-facing README          PASS
Portfolio architecture           PASS
Sanitized examples               PASS
Automated workflow validation    PASS
Deployment/runbook               PASS
Demo recording plan              PASS
Actual short demo video/GIF      PENDING
```

M5 remains `in progress` solely because the actual recording has not yet been produced/reviewed.

M4 Controlled Writes remains deferred and was not touched by M5.
