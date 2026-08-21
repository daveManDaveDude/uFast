# Local release gates

uFast follows D-036: the required release evidence is produced locally on the
development Mac. The authoritative entry point is:

```text
UI_XCRESULT=/absolute/path/to/accepted.xcresult make release-gate
```

The command runs the build, app and core unit tests, lint, analyzer,
local-only checks, release-version/privacy checks, and the UI-result verifier.
It writes a stable JSON manifest under `.derived-data/release-gate/` only when
every child command succeeds. The manifest records a deterministic content
source-freeze identity (including `.swiftlint-analyze-baseline.json`), commit
SHA, clean/dirty state, tool versions, version, build, app/core/UI test counts,
command exit codes, UI evidence and stable result/log paths. The gate rechecks
the source identity, commit, worktree status and version/build immediately
before writing the manifest.

Each gate run builds into a new isolated derived-data directory, records a
post-build digest marker, and requires exactly one case-correct app and widget
`.xcent` input matching that marker. It fails closed when either built input is
missing, duplicated, or changed after the marker; repeated incremental runs do
not rely on filesystem mtimes. The gate enables local simulator signing only
for this isolated preflight so Xcode emits the built entitlement products;
ordinary `make build` retains its unsigned default.

The UI result must have the sidecar
`<result>.source-freeze.json`, created by `scripts/run_ui_tests.sh`. Its content
identity and result digest must still match the current source. A missing,
stale, skipped or otherwise unbound result cannot produce a passing manifest.

A dirty tree may produce candidate evidence for a frozen sprint tree, but its
manifest is explicitly not upload-authorised. `scripts/upload_testflight.sh`
refuses dirty trees and invokes `make release-gate` before incrementing the
build number. The test-only `TESTFLIGHT_GATE_BIN` boundary is used by the
deterministic self-test to execute the real wrapper against fake archive,
export and upload tools; normal uploads use `make release-gate`. The documented
`TESTFLIGHT_SKIP_CHECKS=1` override is reserved
for a clean tree with independently verified evidence; it does not bypass the
transactional increment, concurrent-edit guard or upload controls.

Run the deterministic release negative controls with:

```text
make verify-release-gate
```

This does not perform an archive or upload.
