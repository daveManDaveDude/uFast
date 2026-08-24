# Tracked binary and generated-evidence policy

MNT-013B keeps future generated evidence out of Git by default while retaining
the repository's historical files and legitimate product resources.

## Frozen baseline

`TRACKED_BINARY_BASELINE.json` is an immutable inventory of commit
`7c45dbfaca644845645bb3f76811ebb62cdf1876`. It records the repository-relative
path, byte size and SHA-256 for every then-tracked non-text file at least
1,048,576 bytes and every then-tracked generated-evidence path, including
small files. A path and SHA-256 that still match this manifest is grandfathered.
If its content changes, path alone grants no exception and the new content is
classified again.

The checker recomputes the complete eligible record set from that Git object
and requires the manifest path set, byte sizes and SHA-256 values to match
exactly. The baseline is not regenerated during an ordinary check and is never
a reason to move, delete or recompress the historical file.

## Future evidence rule

The exact checker is `scripts/check_tracked_binary_evidence.py`. A normal run
evaluates tracked modifications and non-ignored untracked files in the working
tree, including ignored untracked paths when they are generated evidence or at
least 1 MiB. Other ignored transient output remains outside the candidate set.
`--base <commit>` evaluates the committed range `<commit>..HEAD` using the
explicitly supplied commit and also rechecks every current baseline path
against the frozen SHA; it never guesses a remote, merge base or branch.
Deleted baseline files fail the check in both modes.

The following are generated evidence at any size:

- paths below `artifacts/`, `.testflight-archives/` or `.derived-data/`;
- files or bundle members whose path component ends in `.xcresult`,
  `.xcarchive`, `.trace`, `.mp4`, `.mov`, `.zip` or `.log`.

Every new or changed generated-evidence file and every new or changed file at
least 1,048,576 bytes requires one exact entry in
`TRACKED_BINARY_ALLOWLIST.json`. Small, non-generated app resources remain
valid without an entry. New or changed resources inside an `.xcassets` catalog
are not otherwise exempt: at least 1 MiB still requires review and an exact
entry. A future design golden follows the same rule.

## Allowlist review

The allowlist is intentionally empty until a specific long-term purpose is
reviewed. Each entry has exactly these fields:

```json
{
  "path": "uFast/Resources/Assets.xcassets/Example.imageset/Example.png",
  "sha256": "<64 lowercase hexadecimal characters>",
  "max_bytes": 1200000,
  "purpose": "Reviewed long-term app resource used by the product",
  "owner_category": "app-resource",
  "review_note": "Why retaining this exact resource is intentional."
}
```

`path` is an exact repository-relative path; wildcards are forbidden. The
SHA-256 must match the content and the content must not exceed `max_bytes`.
`owner_category` is one of `app-resource`, `design-golden` or
`release-evidence`. The purpose must describe a specific long-term reason, and
the review note records the decision context. Temporary output, generic test
fixtures and unreviewed generated evidence do not qualify. Test fixtures used
by the checker are created in temporary directories and are never committed.

## Ignore rules and retention

Future output locations are ignored in `.gitignore`: `.derived-data/`,
`.testflight-archives/`, `artifacts/` and the generated-evidence extensions.
Ignore rules keep routine output out of Git; the checker still rejects an
ignored generated-evidence or large file unless its exact content is reviewed.
They do not grandfather a file that is force-added, nor do they make an
allowlist entry unnecessary. Existing tracked evidence remains exactly where
it is. Source-bound results continue under `.derived-data/sprint-results/`; no
external storage service is selected by this policy.

Run the focused checks with:

```text
python3 scripts/check_tracked_binary_evidence.py --self-test
python3 scripts/check_tracked_binary_evidence.py
python3 scripts/check_tracked_binary_evidence.py --base 7c45dbf
```

The first command uses temporary negative fixtures for a small log, large
random binary, changed grandfathered file, sub-1 MiB app asset and reviewed
large app asset. It does not write repository fixtures.
