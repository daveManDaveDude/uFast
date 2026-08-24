#!/bin/zsh

# Upload is deliberately a thin transactional wrapper around make release-gate.
# A real upload is never authorised from a dirty tree. TESTFLIGHT_SKIP_CHECKS=1
# is the documented emergency escape hatch for an already independently
# verified, clean source tree; it does not relax the clean-tree or mutation
# guards.

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly project="uFast.xcodeproj"
readonly scheme="uFast"
readonly project_file="$project_root/project.yml"
readonly export_options="$project_root/scripts/testflight-export-options.plist"
readonly archive_root="${TESTFLIGHT_ARCHIVE_ROOT:-$project_root/.testflight-archives}"
readonly xcodebuild_bin="${XCODEBUILD_BIN:-xcodebuild}"
readonly xcodegen_bin="${XCODEGEN_BIN:-xcodegen}"
readonly release_gate_bin="${TESTFLIGHT_GATE_BIN:-}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$project_root"

if [[ "${1:-}" == "--self-test" ]]; then
  exec python3 scripts/release_gate.py --upload-self-test
fi

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  print -u2 "Xcode was not found at $DEVELOPER_DIR."
  exit 1
fi

if ! command -v "$xcodegen_bin" >/dev/null 2>&1; then
  print -u2 "XcodeGen is required. Run 'make bootstrap' first."
  exit 1
fi

if ! command -v "$xcodebuild_bin" >/dev/null 2>&1; then
  print -u2 "xcodebuild is required."
  exit 1
fi

if [[ ! -f "$export_options" ]]; then
  print -u2 "TestFlight export options are missing at $export_options."
  exit 1
fi

if [[ ! -f "$project_file" ]]; then
  print -u2 "Missing project configuration at $project_file."
  exit 1
fi

if [[ -n "$release_gate_bin" && "${TESTFLIGHT_SELF_TEST_MODE:-0}" != "1" ]]; then
  print -u2 "TESTFLIGHT_GATE_BIN is restricted to the explicit upload self-test mode."
  exit 1
fi

initial_status="$(git status --porcelain)"
if [[ -n "$initial_status" ]]; then
  print -u2 "Upload refused: the source tree is dirty. Commit the accepted source before uploading."
  print -u2 -- "$initial_status"
  exit 1
fi

snapshot_file="$(mktemp "${TMPDIR:-/tmp}/uFast-project.XXXXXX")"
expected_file="$(mktemp "${TMPDIR:-/tmp}/uFast-project-expected.XXXXXX")"
cleanup_snapshots() {
  rm -f "$snapshot_file" "$expected_file"
}
trap cleanup_snapshots EXIT
cp -p "$project_file" "$snapshot_file"

if [[ "${TESTFLIGHT_SKIP_CHECKS:-0}" == "1" ]]; then
  print "TESTFLIGHT_SKIP_CHECKS=1: release gate skipped by explicit documented override."
else
  print "Running authoritative local release gate before incrementing the build…"
  if [[ -n "$release_gate_bin" ]]; then
    "$release_gate_bin"
  elif [[ -n "${UI_XCRESULT:-}" ]]; then
    UI_XCRESULT="$UI_XCRESULT" make release-gate
  else
    make release-gate
  fi
fi

current_build="$(awk '/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*[0-9]+[[:space:]]*$/ { print $2; exit }' "$project_file")"
marketing_version="$(awk '/^[[:space:]]*MARKETING_VERSION:[[:space:]]*/ { print $2; exit }' "$project_file")"

if [[ -z "$current_build" || -z "$marketing_version" ]]; then
  print -u2 "Could not read CURRENT_PROJECT_VERSION or MARKETING_VERSION from $project_file."
  exit 1
fi

next_build=$((current_build + 1))

cp -p "$snapshot_file" "$expected_file"
NEXT_BUILD="$next_build" /usr/bin/perl -0pi -e \
  's/^([ \t]*CURRENT_PROJECT_VERSION:[ \t]*)\d+[ \t]*$/$1 . $ENV{NEXT_BUILD}/me' \
  "$project_file"
NEXT_BUILD="$next_build" /usr/bin/perl -0pi -e \
  's/^([ \t]*CURRENT_PROJECT_VERSION:[ \t]*)\d+[ \t]*$/$1 . $ENV{NEXT_BUILD}/me' \
  "$expected_file"

if ! cmp -s "$project_file" "$expected_file"; then
  print -u2 "Failed to update CURRENT_PROJECT_VERSION in project.yml exactly."
  exit 1
fi

ensure_increment_is_only_change() {
  local status_line
  status_line="$(git status --porcelain)"
  if [[ "$status_line" != " M project.yml" && "$status_line" != "M  project.yml" ]]; then
    print -u2 "Upload stopped: concurrent or unrelated edits detected after build increment."
    print -u2 -- "$status_line"
    return 1
  fi
  if ! cmp -s "$project_file" "$expected_file"; then
    print -u2 "Upload stopped: project.yml changed beyond the script's build increment."
    return 1
  fi
}

restore_failed_increment() {
  if ensure_increment_is_only_change; then
    cp -p "$snapshot_file" "$project_file"
    print "Restored exact pre-run project.yml after failed upload transaction."
  else
    print -u2 "Did not restore project.yml because unrelated or concurrent edits must not be overwritten."
  fi
}

if ! ensure_increment_is_only_change; then
  exit 1
fi

mkdir -p "$archive_root"

readonly archive_path="$archive_root/uFast-${marketing_version}-${next_build}.xcarchive"
readonly export_path="$archive_root/uFast-${marketing_version}-${next_build}-upload"

print "Archiving uFast ${marketing_version} (${next_build})…"
if ! "$xcodegen_bin" generate; then
  restore_failed_increment
  exit 1
fi
if ! ensure_increment_is_only_change; then
  exit 1
fi
if ! DEVELOPER_DIR="$DEVELOPER_DIR" "$xcodebuild_bin" \
  -project "$project" \
  -scheme "$scheme" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  archive
then
  restore_failed_increment
  exit 1
fi
if ! ensure_increment_is_only_change; then
  exit 1
fi

print "Uploading uFast ${marketing_version} (${next_build}) to App Store Connect…"
if ! DEVELOPER_DIR="$DEVELOPER_DIR" "$xcodebuild_bin" \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates
then
  restore_failed_increment
  exit 1
fi
if ! ensure_increment_is_only_change; then
  exit 1
fi

print "Upload submitted: uFast ${marketing_version} (${next_build})."
print "App Store Connect will process the build before TestFlight makes it available."
