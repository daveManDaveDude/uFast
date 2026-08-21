# Clean-session prompt — post-MVP maintainability sprint

Use this prompt in a new Codex session rooted at `/Users/david/uFast`:

```text
$implement-sprint docs/POST_MVP_MAINTAINABILITY_SPRINT.md

Run the sprint exactly as written using the standard sequential Luna xhigh
story-worker workflow and independent read-only Sol story/integration gates.

Important operating constraints:

- Read AGENTS.md, the implement-sprint skill and the complete sprint document
  before delegating or editing.
- Preserve every pre-existing user change; do not reset, clean, checkout,
  commit, push, open a PR, upload a build or modify App Store Connect.
- MNT-001/GitHub Actions is intentionally out of scope. I am a solo developer
  and the sprint should make the local quality/release evidence authoritative
  and source-bound.
- Execute one story at a time in the dependency order in the sprint document.
- Use Luna xhigh for implementation and a fresh read-only Sol gate for each
  story. Follow the repository circuit breaker before any Terra rescue.
- After Sol ACCEPTS each story, build and deploy that exact accepted source to
  my configured development iPhone when connected, report HUMAN BUILD CHECK
  REQUIRED with the story-specific checklist, and STOP. Do not inspect,
  delegate or begin the next story until I reply HUMAN CHECK PASSED or explicitly
  authorise a recorded skip.
- If I report a device problem, reopen the same story, correct it through the
  normal Luna workflow, obtain a new Sol verdict for changed source/tests,
  redeploy and pause for the human check again.
- MNT-008F is a test-only feasibility story. It must leave the deployable app on
  V4 and produce a separately Sol-reviewed implementation story. Do not make or
  deploy a production V5 migration in this sprint. The later implementation
  sprint must obtain my explicit device-data authorization first. Never
  uninstall/reset the app or delete data to make a migration test pass.
- Run focused tests during each story. Do not run the full four-worker UI suite
  until every story is Sol-accepted, every human gate is recorded and the
  integrated product/test source is frozen. Then run it once, verify the
  .xcresult, and obtain the final independent Sol integration decision.

Begin with Phase 1 only: inspect status and authoritative documents, validate
that every story is executable, complete the Xcode test preflight, and publish
the sprint ledger plus acceptance-to-observability/dependency summary before
starting MNT-002.
```
