# Sol → Luna sprint workflow

This repository has a project-scoped Codex setup for durable, story-level sprint
orchestration. Sol is the parent technical lead and acceptance authority;
`story_worker` is the bounded Luna implementation worker.

## Starting a sprint

From the repository root, invoke the skill with a complete sprint-ready document:

```text
$implement-sprint docs/sprints/sprint-007.md
```

The supplied path may also point to a story pack such as `READY_STORIES.md`, as
long as it contains the stories, dependencies, and acceptance criteria Sol needs.

## What happens automatically

```text
Sol reads and plans the sprint
→ Luna implements one bounded story
→ Luna returns a structured handoff
→ Sol inspects the actual diff and tests
→ Luna fixes precise review feedback when needed
→ Sol re-reviews and accepts the story
→ next story
→ final Sol integration review and validation
```

Stories are tracked in the conversation as `PENDING`, `IN PROGRESS`, `IN REVIEW`,
`CHANGES REQUESTED`, `ACCEPTED`, or `BLOCKED`. Write-heavy work is intentionally
sequential so that each accepted story is a known foundation for the next one.

## What to expect

- Each Luna cycle ends with `STORY IMPLEMENTATION HANDOFF`, including changed
  files, tests, validation, evidence for every acceptance criterion, self-review,
  assumptions, risks, and scope.
- A handoff is evidence, not approval. Sol independently checks the repository's
  real diff, implementation, architecture, tests, regressions, and scope.
- If Sol finds a defect or missing evidence, the story becomes `CHANGES REQUESTED`
  and the same Luna worker receives precise feedback. Luna returns a complete new
  handoff, and Sol reviews again.
- Only Sol may say `STORY ACCEPTED` and move to the next dependent story.
- After all stories are accepted, Sol performs a separate combined-diff review,
  runs the appropriate full build/test/lint/static-analysis suite, checks the
  repository status, and returns a `SPRINT COMPLETE` report.

The project configuration is in `.codex/config.toml`; the Luna worker contract is
in `.codex/agents/story-worker.toml`; the reusable workflow is in
`.agents/skills/implement-sprint/SKILL.md`.
