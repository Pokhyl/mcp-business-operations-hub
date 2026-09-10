# Deployment and Operations Runbook

This runbook covers safe maintenance of the existing production MCP project. It does not replace VPS provisioning documentation and does not assume that an arbitrary server checkout is current.

## Source of truth

GitHub repository:

```text
Pokhyl/mcp-business-operations-hub
```

GitHub is authoritative for project state, exported workflows, documentation, migrations, and acceptance evidence.

Do not trust an older or dirty VPS checkout over the connected GitHub repository.

Before any meaningful change, read:

```text
docs/CURRENT_STATE.md
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/MCP_TOOLS.md
docs/SECURITY.md
```

For CRM work also read the relevant M3 acceptance documents.

## Production endpoint

Current production n8n:

```text
https://publisher.hodor.com.pl
```

Current documented runtime:

```text
n8n 2.37.10
```

Health endpoint:

```text
https://publisher.hodor.com.pl/healthz
```

A successful release must not be considered complete if the health endpoint fails.

## Change classes

### Documentation-only change

Examples:

- README updates;
- architecture documentation;
- portfolio examples;
- runbook updates.

These changes do not require a production deployment, but repository validation/CI must remain green.

### Workflow change

Examples:

- adding or changing an MCP tool;
- changing audit behavior;
- changing a synchronization workflow;
- fixing normalization or provider error handling.

Required release sequence:

```text
inspect current GitHub source
-> inspect current production workflow
-> make the smallest systemic change
-> deploy/publish workflow
-> health check
-> low-level production test
-> audit verification
-> natural-language MCP E2E test when relevant
-> export exact published production workflow
-> update GitHub export
-> synchronize docs/current state
```

Do not leave production newer than GitHub.

### Database migration

Database changes must be represented as migration files under:

```text
database/migrations/
```

Rules:

- model-facing business reads must continue to use the `mcp_readonly` boundary;
- new read tables require explicit `SELECT` permission for the read-only role if they are exposed to MCP;
- do not grant INSERT/UPDATE/DELETE merely to fix a missing read permission;
- synchronization tables may be written only by internal infrastructure workflows/credentials;
- migrations and acceptance evidence must be committed after verification.

## Pre-change checks

Before editing production behavior:

1. Confirm the exact workflow and workflow ID from `docs/CURRENT_STATE.md` or the relevant acceptance document.
2. Verify the currently published production version before making assumptions from an old export.
3. Confirm whether the change affects the aggregate `MCP — Server` tool surface.
4. Confirm the required credential boundary and whether the operation is read-only.
5. Check provider API documentation before introducing a new endpoint, include, filter, or mutation.
6. Do not invent unsupported provider operations.

## MCP gateway changes

The aggregate workflow is:

```text
MCP — Server
workflow_id: dSohghXnQp078EZm
```

The gateway should contain tool exposure/routing, not provider-specific business logic.

After **every** gateway edit, verify the complete expected tool list. Adding one tool is not accepted if another previously accepted tool disappears.

Current expected count:

```text
17 read-only tools
```

The exact names are maintained in `docs/CURRENT_STATE.md` and `docs/MCP_TOOLS.md`.

## Audit acceptance

For valid audited reads the expected path is:

```text
validate
-> audit start
-> provider/database read
-> normalize
-> audit finish
-> return original MCP response
```

Required rules:

- `INVALID_INPUT` is rejected before provider/database access and before audit start;
- successful calls finalize as `succeeded`;
- provider/application failures finalize as `failed` with a normalized error code;
- finish-audit mappings omit `arguments_json` rather than overwriting it with `{}`;
- sensitive search strings remain redacted.

Examples of sensitive inputs that must not be stored raw:

```text
Gmail search query
CRM customer search query
manager search text where treated as sensitive
credentials/tokens/session material
```

## Provider acceptance

A workflow execution marked successful is not enough to prove data correctness.

When a change involves pagination, synchronization, or large provider datasets, acceptance must verify data integrity against the provider.

The KeyCRM pipeline bootstrap previously completed successfully while still missing records because live inserts shifted page boundaries. Count reconciliation detected the discrepancy. Therefore long synchronization jobs require provider/local reconciliation, not only workflow status checks.

## Synchronization rules

Current permanent KeyCRM synchronization uses 15-minute schedules.

General rules:

```text
load previous checkpoint
-> apply overlap where documented
-> read provider pages within rate limits
-> deduplicate stable entity IDs
-> UPSERT local read model
-> advance checkpoint only after successful data write
```

Do not advance a checkpoint before the corresponding local write succeeds.

Observed reassignment history starts only from the documented tracking boundary. Never fabricate historical changes before that boundary.

## Error handling

Return normalized application errors rather than raw provider stack traces.

Expected error vocabulary includes:

```text
AUTH_ERROR
INVALID_INPUT
NOT_FOUND
RATE_LIMIT
TIMEOUT
UPSTREAM_ERROR
INTERNAL_ERROR
```

Tools may add documented domain-specific errors such as `AMBIGUOUS_ATTACHMENT` or `AMBIGUOUS_MANAGER`.

## Workflow export validation

All committed n8n workflow JSON files are automatically validated by:

```text
scripts/validate_n8n_exports.py
.github/workflows/validate-n8n-exports.yml
```

Local command:

```bash
python scripts/validate_n8n_exports.py
```

The validator checks:

- JSON parses successfully;
- export root is a workflow object or non-empty workflow array;
- workflow name is present;
- `nodes` is an array;
- `connections` is an object;
- node names/types are present;
- duplicate node names/IDs are rejected;
- connection sources/targets reference existing nodes.

CI runs on relevant pushes and pull requests.

## Runtime changes

Runtime upgrades are higher-risk than normal workflow edits.

Before changing the n8n runtime:

1. Create a restorable backup of the current production state.
2. Record the current version.
3. Identify the concrete runtime defect or required compatibility reason.
4. Prefer a supported runtime fix over workflow-specific bypass logic.
5. After the upgrade, verify health and rerun the regression that motivated the change.
6. Recheck critical MCP tools before declaring success.
7. Update `docs/CURRENT_STATE.md` and related evidence.

The project previously used this process when upgrading from n8n `2.33.3` to `2.37.10` to resolve HTTP error-output routing behavior.

## KeyCRM boundaries

M3 CRM integration is complete.

Current user-facing KeyCRM tools remain read-only. The public KeyCRM API currently does not expose CRM-native chat/message history through a supported endpoint. Do not:

- invent `/messages` or `/chats` endpoints;
- scrape the KeyCRM UI;
- silently substitute Gmail for CRM-native communication history;
- use private/internal UI interfaces without a separate explicit architecture/security decision.

See:

```text
docs/M3_KEYCRM_COMMUNICATIONS_API.md
```

## Controlled writes

M4 is deferred by explicit project decision.

Do not introduce write scopes, write credentials, or state-changing MCP tools unless M4 is explicitly resumed.

When resumed, the planned boundary remains:

```text
separate write-tool class
explicit approval
idempotency
full audit trail
```

Existing read-only credentials and tools must not be weakened to implement writes.

## Rollback principle

If a production workflow change causes a regression:

1. Stop expanding the change.
2. Identify the last accepted published workflow version/export.
3. Restore the known-good behavior rather than layering emergency bypasses onto an unknown state.
4. Re-run health, low-level acceptance, audit checks, and affected natural-language tests.
5. Export the restored production state and synchronize GitHub if the rollback changes the authoritative version.
6. Document the defect and rollback cause so the same failure is not reintroduced.

## Release completion checklist

A production workflow change is complete only when all applicable items are true:

```text
[ ] exact current workflow inspected
[ ] systemic change implemented
[ ] production workflow published
[ ] health check passed
[ ] low-level acceptance passed
[ ] audit behavior verified
[ ] natural-language MCP E2E passed where relevant
[ ] complete gateway tool surface verified if gateway changed
[ ] exact production workflow exported
[ ] GitHub export synchronized
[ ] documentation/current state synchronized
[ ] CI validation green
```

Documentation-only M5 work does not require a production deployment, but it must not claim production changes that were not actually made.
