# M3 KeyCRM manager customer statistics acceptance

Last verified: 2026-09-09.

## Goal

Provide a read-only MCP capability for natural-language questions such as:

```text
Сколько всего клиентов у менеджера Анастасия Быкова?
```

The implementation must not scan the full KeyCRM buyer dataset on every request and must not expose CRM write access.

## Data model

`public.keycrm_customers` stores the minimal search fields plus:

```text
manager_id bigint
```

Index:

```text
idx_keycrm_customers_manager_id
```

Migration:

```text
database/migrations/004_keycrm_manager_id.sql
```

The user-facing PostgreSQL credential remains read-only:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

The full bootstrap and permanent 15-minute incremental synchronization both persist `manager_id`.

## Manager resolution

The workflow resolves managers through the read-only KeyCRM users endpoint:

```text
GET /users
filter[status]=active
```

Natural manager names are matched with Cyrillic/Latin transliteration-aware fuzzy comparison. Ambiguous matches are rejected instead of silently selecting a user.

## MCP tool

```text
Tool:        get_manager_customer_stats
Workflow:    MCP — KeyCRM Manager Customer Stats
workflow_id: KcrmMgrStatsA7pQ4Z
status:      active
```

Input:

```json
{
  "manager": "string"
}
```

Execution path:

```text
validate
 -> audit start
 -> GET active KeyCRM users
 -> resolve manager
 -> read-only PostgreSQL count by manager_id
 -> normalize
 -> audit finish
 -> return
```

Manager-name audit arguments are redacted.

## Production acceptance

Low-level production test:

```text
input:          Анастасия Быкова
resolved user:  Anastasiia Bykova
manager_id:     4
success:        true
```

Negative cases:

```text
unknown manager -> NOT_FOUND
one-character input -> INVALID_INPUT
```

## Natural-language MCP-client acceptance

PASS on 2026-09-09.

The real MCP client was asked:

```text
сколько всего клиентов у менеджера Анастасия Быкова
```

The client selected the manager-statistics tool and returned the current PostgreSQL count. The point-in-time count was `3382`; the value is expected to change as KeyCRM assignments change and the 15-minute synchronization runs.

This closes the remaining client-level acceptance for `get_manager_customer_stats`.
