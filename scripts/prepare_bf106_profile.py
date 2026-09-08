#!/usr/bin/env python3
"""Create a fresh isolated BF-106 source copy. Never installs or launches apps."""
import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".derived-data/sprint-results/BF-106"
OUTPUT.mkdir(parents=True, exist_ok=True)
destination = pathlib.Path(tempfile.mkdtemp(prefix="isolated-", dir=OUTPUT))
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
).decode().split("\0")
manifest = {}
for name in sorted(set(filter(None, paths))):
    source = ROOT / name
    if not source.is_file():
        continue
    target = destination / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest[name] = hashlib.sha256(source.read_bytes()).hexdigest()

# All app/extension identifiers change together. No production app group may
# resolve even if signing later accidentally supplies a group entitlement.
spec = destination / "project.yml"
spec.write_text(spec.read_text().replace("com.davidmcgrath", "com.davidmcgrath.bf106")
                .replace("              - ufast\n", "              - ufast-bf106\n"))
with spec.open("a") as handle:
    handle.write("""
  BF106ProfileUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: BF106ProfileUITests
    dependencies:
      - target: uFast
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.davidmcgrath.bf106.ProfileUITests
        TEST_TARGET_NAME: uFast
schemes:
  BF106Profile:
    build:
      targets:
        uFast: all
        BF106ProfileUITests: [test]
    test:
      config: Release
      gatherCoverageData: false
      targets:
        - BF106ProfileUITests
    profile:
      config: Release
""")
shared = destination / "LockScreenShared/ActiveFastProjectionFileStore.swift"
shared.write_text(shared.read_text().replace(
    "group.com.davidmcgrath.uFast.widgets", "group.com.davidmcgrath.bf106.disabled"
))
for entitlements in destination.rglob("*.entitlements"):
    with entitlements.open("rb") as handle:
        values = plistlib.load(handle)
    values.pop("com.apple.security.application-groups", None)
    with entitlements.open("wb") as handle:
        plistlib.dump(values, handle)
subprocess.run(["xcodegen", "generate"], cwd=destination, check=True)
manifest_data = {
    "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
    "source_sha256": manifest,
    "transformed_sha256": {
        name: hashlib.sha256((destination / name).read_bytes()).hexdigest()
        for name in manifest if (destination / name).is_file()
    },
    "isolation": "distinct bundle IDs; no app groups; disabled shared-container identifier",
    "configuration": "Release; coverage disabled; optimization inherited from Release",
    "path": str(destination),
}
(destination / "bf106-source-manifest.json").write_text(json.dumps(manifest_data, indent=2))
(destination / "bf106-tracked.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary"], cwd=ROOT))
print(destination)
