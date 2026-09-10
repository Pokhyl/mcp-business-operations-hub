#!/usr/bin/env python3
"""Validate exported n8n workflow JSON files in this repository.

The validator is intentionally dependency-free so it can run locally and in
GitHub Actions with the standard Python runtime.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
N8N_ROOT = REPO_ROOT / "n8n"


def fail(path: Path, message: str, errors: list[str]) -> None:
    errors.append(f"{path.relative_to(REPO_ROOT)}: {message}")


def validate_workflow(path: Path, workflow: Any, index: int, errors: list[str]) -> None:
    label = f"workflow[{index}]"

    if not isinstance(workflow, dict):
        fail(path, f"{label} must be a JSON object", errors)
        return

    name = workflow.get("name")
    if not isinstance(name, str) or not name.strip():
        fail(path, f"{label}.name must be a non-empty string", errors)

    nodes = workflow.get("nodes")
    if not isinstance(nodes, list):
        fail(path, f"{label}.nodes must be an array", errors)
        return

    connections = workflow.get("connections")
    if not isinstance(connections, dict):
        fail(path, f"{label}.connections must be an object", errors)

    node_names: set[str] = set()
    node_ids: set[str] = set()

    for node_index, node in enumerate(nodes):
        node_label = f"{label}.nodes[{node_index}]"
        if not isinstance(node, dict):
            fail(path, f"{node_label} must be an object", errors)
            continue

        node_name = node.get("name")
        node_type = node.get("type")
        node_id = node.get("id")

        if not isinstance(node_name, str) or not node_name.strip():
            fail(path, f"{node_label}.name must be a non-empty string", errors)
        elif node_name in node_names:
            fail(path, f"duplicate node name: {node_name!r}", errors)
        else:
            node_names.add(node_name)

        if not isinstance(node_type, str) or not node_type.strip():
            fail(path, f"{node_label}.type must be a non-empty string", errors)

        if node_id is not None:
            if not isinstance(node_id, str) or not node_id.strip():
                fail(path, f"{node_label}.id must be a non-empty string when present", errors)
            elif node_id in node_ids:
                fail(path, f"duplicate node id: {node_id!r}", errors)
            else:
                node_ids.add(node_id)

    if isinstance(connections, dict):
        for source_name, groups in connections.items():
            if source_name not in node_names:
                fail(path, f"connection source references unknown node {source_name!r}", errors)

            if not isinstance(groups, dict):
                fail(path, f"connections[{source_name!r}] must be an object", errors)
                continue

            for output_group in groups.values():
                if not isinstance(output_group, list):
                    continue
                for branch in output_group:
                    if not isinstance(branch, list):
                        continue
                    for target in branch:
                        if not isinstance(target, dict):
                            continue
                        target_name = target.get("node")
                        if isinstance(target_name, str) and target_name not in node_names:
                            fail(
                                path,
                                f"connection target references unknown node {target_name!r}",
                                errors,
                            )


def validate_file(path: Path, errors: list[str]) -> int:
    try:
        with path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except json.JSONDecodeError as exc:
        fail(path, f"invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}", errors)
        return 0
    except OSError as exc:
        fail(path, f"cannot read file: {exc}", errors)
        return 0

    if isinstance(payload, list):
        workflows = payload
    elif isinstance(payload, dict):
        workflows = [payload]
    else:
        fail(path, "root must be a workflow object or an array of workflow objects", errors)
        return 0

    if not workflows:
        fail(path, "workflow export array must not be empty", errors)
        return 0

    for index, workflow in enumerate(workflows):
        validate_workflow(path, workflow, index, errors)

    return len(workflows)


def main() -> int:
    if not N8N_ROOT.is_dir():
        print("ERROR: n8n directory not found", file=sys.stderr)
        return 1

    files = sorted(N8N_ROOT.rglob("*.json"))
    if not files:
        print("ERROR: no n8n JSON exports found", file=sys.stderr)
        return 1

    errors: list[str] = []
    workflow_count = 0

    for path in files:
        workflow_count += validate_file(path, errors)

    if errors:
        print("n8n export validation FAILED", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        print(
            f"Checked {len(files)} JSON files / {workflow_count} workflow objects; "
            f"found {len(errors)} error(s).",
            file=sys.stderr,
        )
        return 1

    print(
        f"n8n export validation PASSED: {len(files)} JSON files / "
        f"{workflow_count} workflow objects"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
