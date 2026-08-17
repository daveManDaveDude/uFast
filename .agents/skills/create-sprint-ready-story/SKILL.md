---
name: create-sprint-ready-story
description: "Create or refine implementation-ready sprint stories for the repository, either as standalone Markdown documents or as additions to a backlog or ready-stories document. Use when a user asks to turn an idea, bug, review finding, UX change, or product decision into a story that can be executed by the $implement-sprint skill, or asks to add that story to BACKLOG.md, READY_STORIES.md, or a slice sprint document."
---

# Create Sprint Ready Story

Create a bounded story artifact; do not implement product code. Use the existing
`implement-sprint` skill as the execution contract, keep Luna responsible for
research, drafting and document edits, and use one read-only Sol gate for
readiness decisions that require product or technical judgment.

## Operating rules

- Read `.agents/skills/implement-sprint/SKILL.md` completely before drafting.
  Do not duplicate its implementation workflow or invent a competing handoff
  format.
- Preserve unrelated edits. Never reset, clean, reformat, or overwrite a
  document section outside the requested story.
- This skill writes planning artifacts only. Do not edit product source, tests,
  project files, generated Xcode files, or implementation configuration.
- A story is `Ready` only when its outcome, scope, acceptance criteria,
  dependencies, decisions, architecture boundaries, validation, executability,
  and test observability are clear. Every acceptance criterion must map to an
  observable result and a verification surface. Use `Draft` when a material decision or
  reproduction remains unresolved; never hide uncertainty in implementation
  wording.
- Treat existing fixture seeds, legacy tests, and shared journeys as explicit
  dependencies. A story that changes a domain invariant must identify the
  downstream fixtures and tests whose assumptions may need to change.
- Do not claim that a worker, reviewer, or draft has accepted the story. Record
  the explicit Sol readiness verdict when a Sol gate is used.
- Never commit or push changes unless the user separately asks.

## Workflow

### 1. Resolve the output mode

Infer the smallest safe operation from the request:

- **Standalone story:** create or update the requested Markdown path. If no path
  is supplied but the repository convention is clear, use
  `docs/<story-id>_<short-slug>_STORY.md`; otherwise ask for the path.
- **Backlog update:** edit the named backlog document in place. Preserve its
  heading hierarchy, ordering, status vocabulary and link style.
- **Both:** create the complete story document and add the smallest appropriate
  index/backlink entry to the backlog.

If the user names an existing story or path, refine it rather than creating a
duplicate. Search for the story ID and distinctive title before choosing a new
ID. If no ID is provided, follow the target document's namespace and numbering
pattern; stop for human direction when the next ID is ambiguous or collides.

### 2. Build only the context needed

Read, in this order:

1. The repository `AGENTS.md` files.
2. `.agents/skills/implement-sprint/SKILL.md`.
3. The target backlog/story/sprint document and nearby examples.
4. For product behavior, the relevant sections of `PRODUCT.md`, `MVP_SCOPE.md`,
   `DOMAIN_RULES.md`, `DECISIONS.md`, and the current backlog. Read complete
   authoritative documents when the story crosses multiple domains; otherwise
   use targeted searches before opening only the needed sections.
5. The current implementation and tests only far enough to name real boundaries,
   preserve existing behavior, identify dependencies, and avoid proposing work
   already delivered.

Do not reread the complete repository or sprint history for every revision.
Maintain a compact context record containing authoritative paths, relevant
decisions, existing story IDs, affected components, and unresolved questions.

### 3. Draft the story

Use the target document's existing format. For a new or materially revised
story, include these sections unless the target convention clearly names them
differently:

- title and stable story ID;
- epic/slice, priority and status (`Ready`, `Draft`, `Blocked`, or the local equivalent);
- user outcome and why now;
- context and authoritative product rules/decisions;
- in scope and out of scope;
- final user-visible behavior and negative/edge cases;
- acceptance criteria, preferably Given/When/Then and independently testable;
- architecture and data boundaries, including persistence, migration,
  concurrency, privacy, accessibility and compatibility constraints when relevant;
- dependencies and explicit product decisions;
- focused verification, integration verification and human checks;
- an acceptance-to-observability matrix covering each criterion, its expected
  result, test layer/path, negative or edge path, and required artifact;
- a downstream-fixture and legacy-suite impact inventory for changed domain,
  persistence, navigation, or user-visible behavior;
- an execution profile containing uncertainty (`low`, `medium`, or `high`),
  deterministic reproduction, required observability, expected expensive
  commands, focused correction budget, and maximum rescue tier;
- a concise Definition of Ready.

Keep the story bounded to one coherent outcome. Separate implementation
constraints from acceptance behavior. Do not prescribe file names or a design
that repository inspection does not support. Do not add AI, cloud sync, health
claims, monetization, analytics, or other out-of-scope capability merely because
it could be useful.

Use Luna xhigh as the default implementer because it is the repository's
cost-effective normal path. Recommend Terra at the outset only when the user
requests it or when a deterministic reproduction already shows material
cross-cutting complexity. Otherwise give Luna one bounded diagnostic pass and
use the `implement-sprint` circuit breaker if uncertainty remains.

Use this compact execution profile in the story:

```text
Execution profile:
- Uncertainty: low | medium | high
- Initial implementer: Luna xhigh | Terra medium
- Deterministic reproduction and observability: ...
- Acceptance matrix and downstream fixture/legacy-suite impact: ...
- Focused correction budget: ...
- Expected expensive commands: ...
- Maximum rescue tier: Terra | Sol diagnosis
```

Before marking a story `Ready`, include a compact matrix in the story or its
linked verification section:

```text
| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
|----|-------------------|-----------------|--------------------|----------|
| AC1 | ...               | ...             | ...                | ...      |
```

For every impacted interactive flow, name the stable accessibility identifier
or semantic query that tests should use. Do not leave selectors to be inferred
from visible labels after implementation. For every changed invariant, list
the existing fixture seeds and legacy suites that must remain valid or be
updated deliberately. Include static analysis (normally `make analyze`) in the
focused or integration verification plan when source changes are involved.

Do not mark a combined investigation-and-fix story `Ready` when deterministic
reproduction or observable acceptance is missing, or when investigation may
cross multiple architecture boundaries without a bounded diagnostic outcome.
Split it into a discovery story and a bounded implementation story when
acceptance depends on exploratory native gestures, temporary evidence, several
independent unknowns, or a test harness that does not yet expose the required
state. Terms such as “slightly,” “looks correct,” or “equivalent evidence”
require a deterministic observable definition before readiness.

For a compact ledger such as `BACKLOG.md`, add one index entry and link the
complete story document when the existing convention stores details elsewhere.
For a detailed document such as `READY_STORIES.md` or a slice story file,
insert the complete story in the established order and style.

### 4. Use the Sol readiness gate selectively

Use one Sol gate after the draft is complete when any of these are true:

- the story introduces or changes product behavior;
- a product decision, contradiction, scope boundary, or dependency is material;
- persistence, migration, concurrency, privacy, accessibility, health-related
  language, external integrations, or cross-cutting architecture is involved;
- the story is intended to be marked `Ready` for `implement-sprint`.

Skip Sol only for a mechanical operation such as reformatting an already
approved story or inserting an unchanged, already-decided entry. Record
`Sol gate: not required — mechanical update` in the report.

Spawn the reviewer as a read-only default agent with:

- `model: gpt-5.6-sol`;
- `reasoning_effort: medium` by default, escalating to `high` only for material
  architecture, persistence, security, ambiguity, or disagreement;
- `fork_context: false`.

Give Sol only a compact packet: the proposed story, acceptance-to-observability
matrix, downstream fixture/legacy-suite inventory, authoritative references,
existing related stories, affected boundaries, unresolved questions, execution
profile, and requested output mode. Ask whether discovery and implementation
must be split. Tell Sol not to edit files, implement code, or rewrite the story.
Require this response:

```text
STORY READINESS DECISION
Verdict: READY | NEEDS_CHANGES | BLOCKED
Product decision status:
Scope and acceptance status:
Test observability and fixture-impact status:
Architecture/data/accessibility/privacy status:
Execution profile and testability status:
Recommended initial implementer: Luna xhigh | Terra medium
Split required: yes | no
Missing evidence or contradictions:
Required changes:
Reasoning effort: medium 
```

If `NEEDS_CHANGES`, Luna applies only the required document changes, preserves
the same story ID, and sends the compact revised packet to the same Sol reviewer
when possible. If `BLOCKED`, do not mark the story `Ready`; either record it as
`Draft` with the blocker when the user asked to capture it, or stop and ask for
the missing decision.

If Sol delegation is unavailable, do not simulate a verdict and do not use
`Ready for Sol review` as a status. Write or report the artifact as `Draft` with
`Sol gate: pending` (or `Blocked` when the missing review prevents safe capture).
Only an explicit Sol `READY` verdict permits the final status `Ready`.

### 5. Write and report

Use `apply_patch` for document edits. Recheck the final file for:

- duplicate IDs or headings;
- broken relative links;
- unresolved placeholders or contradictory status/criteria;
- acceptance criteria that cannot be tested;
- acceptance criteria missing from the observability matrix;
- missing downstream fixture or legacy-suite impact analysis;
- missing execution profile, deterministic observability, or correction budget;
- an unresolved investigation bundled into implementation;
- accidental changes outside the requested artifact.

Return a compact handoff:

```text
SPRINT STORY READY | SPRINT STORY DRAFT | SPRINT STORY BLOCKED

Story: <ID> — <title>
Status: Ready | Draft | Blocked
Artifact: <path>
Backlog update: <path and entry, or none>
Sol gate: <verdict, or mechanical update not required>
Execution profile: <uncertainty, Luna/Terra start, correction budget, rescue tier>
Open decisions / blockers: <none or list>
Implement-sprint handoff: <why this path is ready or what remains>
```

Do not claim sprint implementation has started. The next operation is the
separate `$implement-sprint <path>` workflow.
