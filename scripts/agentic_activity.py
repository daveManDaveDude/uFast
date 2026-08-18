#!/usr/bin/env python3
"""Write and inspect compact activity beacons for sprint workers.

Activity beacons are deliberately kept in generated state so they can be read
by the orchestrator without becoming part of a product or test change.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import tempfile
from datetime import datetime, timezone
from typing import Any


DEFAULT_ACTIVITY_DIR = pathlib.Path(".derived-data/agentic/activity")
STATES = {
    "working",
    "waiting_on_tool",
    "progressing_silently",
    "needs_input",
    "blocked",
    "errored",
    "completed",
}
PHASES = {
    "inspect",
    "edit",
    "compile",
    "focused-test",
    "integration-test",
    "handoff",
}


def activity_dir() -> pathlib.Path:
    configured = os.environ.get("AGENTIC_ACTIVITY_DIR")
    return pathlib.Path(configured) if configured else DEFAULT_ACTIVITY_DIR


def activity_path(worker: str) -> pathlib.Path:
    safe_worker = "".join(character for character in worker if character.isalnum() or character in "-_ ")
    safe_worker = safe_worker.strip().replace(" ", "-")
    if not safe_worker:
        raise ValueError("worker must contain at least one letter or number")
    return activity_dir() / f"{safe_worker}.json"


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def write_record(record: dict[str, Any]) -> pathlib.Path:
    path = activity_path(str(record["worker"]))
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        json.dump(record, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary_path = pathlib.Path(temporary.name)
    os.replace(temporary_path, path)
    return path


def update(args: argparse.Namespace) -> int:
    if args.state not in STATES:
        raise ValueError(f"unsupported state: {args.state}")
    if args.phase not in PHASES:
        raise ValueError(f"unsupported phase: {args.phase}")
    if args.state == "waiting_on_tool" and not args.active_command:
        raise ValueError("waiting_on_tool requires --active-command")

    timestamp = now()
    record = {
        "activity_version": 1,
        "worker": args.worker,
        "story": args.story,
        "state": args.state,
        "phase": args.phase,
        "recorded_at": timestamp,
        "last_meaningful_activity": timestamp,
        "active_command": args.active_command or None,
        "files_touched": sorted(set(args.files_touched)),
        "artifacts_touched": sorted(set(args.artifacts_touched)),
        "hypothesis": args.hypothesis or None,
        "expected_next_evidence": args.expected_next_evidence or None,
        "waiting_on_external_tool": args.waiting_on_external_tool,
        "write_scope": args.write_scope,
    }
    path = write_record(record)
    print(path)
    return 0


def read_records(args: argparse.Namespace) -> int:
    root = activity_dir()
    if not root.exists():
        print("No agentic activity records")
        return 0

    paths = [activity_path(args.worker)] if args.worker else sorted(root.glob("*.json"))
    records = []
    for path in paths:
        if not path.exists():
            continue
        records.append(json.loads(path.read_text(encoding="utf-8")))
    if not records:
        print("No agentic activity records")
    else:
        print(json.dumps(records, indent=2, sort_keys=True))
    return 0


def clear(args: argparse.Namespace) -> int:
    path = activity_path(args.worker)
    if path.exists():
        path.unlink()
        print(path)
    return 0


def self_test() -> int:
    with tempfile.TemporaryDirectory() as temporary:
        previous = os.environ.get("AGENTIC_ACTIVITY_DIR")
        os.environ["AGENTIC_ACTIVITY_DIR"] = temporary
        try:
            arguments = argparse.Namespace(
                worker="luna",
                story="TEST-001",
                state="waiting_on_tool",
                phase="focused-test",
                active_command="make test-unit",
                files_touched=["Sources/Example.swift"],
                artifacts_touched=[".derived-data/test.log"],
                hypothesis="The focused test should pass after the boundary fix.",
                expected_next_evidence="Focused test result and log path.",
                waiting_on_external_tool=True,
                write_scope="story:TEST-001",
            )
            update(arguments)
            record = json.loads((pathlib.Path(temporary) / "luna.json").read_text(encoding="utf-8"))
            assert record["state"] == "waiting_on_tool"
            assert record["phase"] == "focused-test"
            assert record["active_command"] == "make test-unit"
            assert record["files_touched"] == ["Sources/Example.swift"]
            assert record["artifacts_touched"] == [".derived-data/test.log"]
            assert "timeout" not in STATES
        finally:
            if previous is None:
                os.environ.pop("AGENTIC_ACTIVITY_DIR", None)
            else:
                os.environ["AGENTIC_ACTIVITY_DIR"] = previous
    print("Agentic activity self-test passed")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run the local activity contract self-test")
    subparsers = parser.add_subparsers(dest="action")

    update_parser = subparsers.add_parser("update", help="write one worker activity beacon")
    update_parser.add_argument("--worker", required=True)
    update_parser.add_argument("--story", required=True)
    update_parser.add_argument("--state", required=True, choices=sorted(STATES))
    update_parser.add_argument("--phase", required=True, choices=sorted(PHASES))
    update_parser.add_argument("--active-command")
    update_parser.add_argument("--files-touched", nargs="*", default=[])
    update_parser.add_argument("--artifacts-touched", nargs="*", default=[])
    update_parser.add_argument("--hypothesis")
    update_parser.add_argument("--expected-next-evidence")
    update_parser.add_argument("--waiting-on-external-tool", action="store_true")
    update_parser.add_argument("--write-scope", default="story")
    update_parser.set_defaults(handler=update)

    read_parser = subparsers.add_parser("read", help="print worker activity beacons")
    read_parser.add_argument("--worker")
    read_parser.set_defaults(handler=read_records)

    clear_parser = subparsers.add_parser("clear", help="remove one stale or cancelled beacon")
    clear_parser.add_argument("--worker", required=True)
    clear_parser.set_defaults(handler=clear)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not hasattr(args, "handler"):
        parser.error("choose update, read, clear, or --self-test")
    try:
        return args.handler(args)
    except (OSError, ValueError, AssertionError) as error:
        parser.error(str(error))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
