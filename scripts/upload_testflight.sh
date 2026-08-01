#!/bin/zsh
set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly project="uFast.xcodeproj"
readonly scheme="uFast"
readonly project_file="$project_root/project.yml"
readonly export_options="$project_root/scripts/testflight-export-options.plist"
readonly archive_root="${TESTFLIGHT_ARCHIVE_ROOT:-$project_root/.testflight-archives}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$project_root"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  print -u2 "Xcode was not found at $DEVELOPER_DIR."
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  print -u2 "XcodeGen is required. Run 'make bootstrap' first."
  exit 1
fi

if [[ ! -f "$export_options" ]]; then
  print -u2 "TestFlight export options are missing at $export_options."
  exit 1
fi

if [[ "${TESTFLIGHT_SKIP_CHECKS:-0}" != "1" ]]; then
  print "Running unit tests and lint before upload…"
  make test-unit lint
fi

current_build="$(awk '/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*[0-9]+[[:space:]]*$/ { print $2; exit }' "$project_file")"
marketing_version="$(awk '/^[[:space:]]*MARKETING_VERSION:[[:space:]]*/ { print $2; exit }' "$project_file")"

if [[ -z "$current_build" || -z "$marketing_version" ]]; then
  print -u2 "Could not read CURRENT_PROJECT_VERSION or MARKETING_VERSION from $project_file."
  exit 1
fi

next_build=$((current_build + 1))

NEXT_BUILD="$next_build" /usr/bin/perl -0pi -e \
  's/^(\s*CURRENT_PROJECT_VERSION:\s*)\d+\s*$/$1 . $ENV{NEXT_BUILD}/me' \
  "$project_file"

if ! awk -v expected="$next_build" '
  /^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*[0-9]+[[:space:]]*$/ {
    if ($2 == expected) {
      found = 1
    }
  }
  END { exit(found ? 0 : 1) }
' "$project_file"; then
  print -u2 "Failed to update CURRENT_PROJECT_VERSION in $project_file."
  exit 1
fi

mkdir -p "$archive_root"

readonly archive_path="$archive_root/uFast-${marketing_version}-${next_build}.xcarchive"
readonly export_path="$archive_root/uFast-${marketing_version}-${next_build}-upload"

print "Archiving uFast ${marketing_version} (${next_build})…"
xcodegen generate
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  archive

print "Uploading uFast ${marketing_version} (${next_build}) to App Store Connect…"
xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates

print "Upload submitted: uFast ${marketing_version} (${next_build})."
print "App Store Connect will process the build before TestFlight makes it available."
