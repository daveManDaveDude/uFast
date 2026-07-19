#!/bin/zsh
set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly derived_data="${DERIVED_DATA_DEVICE:-$project_root/.derived-data-device}"
readonly bundle_id="${BUNDLE_ID:-com.example.uFast}"

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

device_id="${DEVICE_ID:-}"

if [[ -z "$device_id" ]]; then
  device_output="$(xcrun devicectl list devices)"
  device_ids=("${(@f)$(print -r -- "$device_output" | awk '
    /connected/ && /iPhone/ {
      for (field = 1; field <= NF; field++) {
        if ($field ~ /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/) {
          print $field
        }
      }
    }
  ')}")

  if (( ${#device_ids[@]} == 0 )); then
    print -u2 "No connected iPhone was found. Connect and unlock it, then try again."
    exit 1
  fi

  if (( ${#device_ids[@]} > 1 )); then
    print -u2 "More than one connected iPhone was found."
    print -u2 "Run again with DEVICE_ID=<CoreDevice identifier> make deploy-iphone."
    exit 1
  fi

  device_id="${device_ids[1]}"
fi

device_details="$(xcrun devicectl device info details --device "$device_id")"
device_udid="$(print -r -- "$device_details" | awk '/• udid:/ { print $3; exit }')"
device_name="$(print -r -- "$device_details" | awk -F': ' '/• name:/ { print $2; exit }')"

if [[ -z "$device_udid" ]]; then
  print -u2 "Could not read the iPhone hardware identifier for $device_id."
  exit 1
fi

print "Deploying uFast to ${device_name:-connected iPhone}…"

xcodegen generate

xcodebuild \
  -quiet \
  -project uFast.xcodeproj \
  -scheme uFast \
  -sdk iphoneos \
  -destination "id=$device_udid" \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  build

readonly app_path="$derived_data/Build/Products/Debug-iphoneos/uFast.app"

xcrun devicectl device install app \
  --device "$device_id" \
  "$app_path"

xcrun devicectl device process launch \
  --device "$device_id" \
  "$bundle_id"

print "uFast is installed and running on ${device_name:-your iPhone}."
