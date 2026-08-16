#!/usr/bin/env python3
"""Verify the repository's agentic workflow contract without running workers."""

from __future__ import annotations

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def require(path: pathlib.Path, *needles: str) -> None:
    text = path.read_text(encoding="utf-8").lower()
    missing = [needle for needle in needles if needle.lower() not in text]
    if missing:
        raise AssertionError(f"{path}: missing {missing}")


def main() -> int:
    config = ROOT / ".codex/config.toml"
    worker = ROOT / ".codex/agents/story-worker.toml"
    skill = ROOT / ".agents/skills/implement-sprint/SKILL.md"
    guidance = ROOT / "AGENTS.md"
    wrapper = ROOT / "scripts/run_ui_tests.sh"

    require(config, "max_concurrent_threads_per_session = 1", "write-capable sprint workers are sequential")
    require(
        worker,
        "agentic_activity.py",
        "waiting_on_tool",
        "progressing_silently",
        "Never output STORY ACCEPTED",
    )
    require(
        skill,
        "timeout is an observation",
        "Pre-escalation evidence packet",
        "user override",
        "one Terra rescue",
        "same write scope",
        "exit_code",
    )
    require(
        guidance,
        "timeout is an observation",
        "pre-escalation evidence packet",
        "user override",
        "Terra is one bounded rescue",
    )

    wrapper_text = wrapper.read_text(encoding="utf-8")
    if "status=" in wrapper_text or re.search(r"\bstatus\s*=", wrapper_text):
        raise AssertionError("UI wrapper must not use zsh's read-only status variable")
    require(wrapper, "exit_code=$?", "-resultBundlePath", "UI test xcodebuild exit code")

    print("Agentic configuration verification passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError) as error:
        print(f"Agentic configuration verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
