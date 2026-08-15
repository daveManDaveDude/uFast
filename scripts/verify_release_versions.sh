#!/bin/zsh

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
project_file="$project_root/uFast.xcodeproj"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
verification_derived_data="$(mktemp -d "${TMPDIR:-/tmp}/uFast-release-version.XXXXXX")"
verification_log="$verification_derived_data/build.log"
trap 'rm -rf "$verification_derived_data"' EXIT

if [[ ! -d "$project_file" ]]; then
    print -u2 "Missing generated project: $project_file"
    exit 2
fi

show_build_settings() {
    local target="$1"
    DEVELOPER_DIR="$developer_dir" xcodebuild \
        -project "$project_file" \
        -scheme "$target" \
        -configuration Release \
        -derivedDataPath "$verification_derived_data" \
        -showBuildSettings 2>/dev/null \
        | awk -F ' = ' '/^[[:space:]]*(MARKETING_VERSION|CURRENT_PROJECT_VERSION) = / {
            key = $1
            sub(/^[[:space:]]*/, "", key)
            print key "=" $2
        }'
}

typeset -A app_settings widget_settings
while IFS='=' read -r key value; do
    [[ -n "$key" ]] && app_settings[$key]="$value"
done <<< "$(show_build_settings uFast)"
while IFS='=' read -r key value; do
    [[ -n "$key" ]] && widget_settings[$key]="$value"
done <<< "$(show_build_settings uFastLockScreenWidget)"

app_version="${app_settings[MARKETING_VERSION]:-}"
widget_version="${widget_settings[MARKETING_VERSION]:-}"
app_build="${app_settings[CURRENT_PROJECT_VERSION]:-}"
widget_build="${widget_settings[CURRENT_PROJECT_VERSION]:-}"

if [[ -z "$app_version" || -z "$widget_version" ]]; then
    print -u2 "Release build setting resolution failed for short version: app=$app_version widget=$widget_version"
    exit 1
fi
if [[ -z "$app_build" || -z "$widget_build" ]]; then
    print -u2 "Release build setting resolution failed for build number: app=$app_build widget=$widget_build"
    exit 1
fi

print "Resolved Release settings: app MARKETING_VERSION=$app_version CURRENT_PROJECT_VERSION=$app_build"
print "Resolved Release settings: widget MARKETING_VERSION=$widget_version CURRENT_PROJECT_VERSION=$widget_build"

if [[ "$app_version" != "$widget_version" ]]; then
    print -u2 "Release short-version mismatch: app=$app_version widget=$widget_version"
    exit 1
fi
if [[ "$app_build" != "$widget_build" ]]; then
    print -u2 "Release build-number mismatch: app=$app_build widget=$widget_build"
    exit 1
fi
print "Release setting parity passed: short version=$app_version build number=$app_build"

if ! DEVELOPER_DIR="$developer_dir" xcodebuild \
    -project "$project_file" \
    -scheme uFast \
    -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$verification_derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build >"$verification_log" 2>&1
then
    cat "$verification_log" >&2
    exit 1
fi

app_bundle="$verification_derived_data/Build/Products/Release-iphonesimulator/uFast.app"
processed_app_plist="$app_bundle/Info.plist"
processed_widget_plist="$app_bundle/PlugIns/uFast Lock Screen Widget.appex/Info.plist"

if [[ ! -f "$processed_app_plist" || ! -f "$processed_widget_plist" ]]; then
    print -u2 "Processed plist assertion failed: Release build did not produce both app and widget Info.plists."
    print -u2 "App: $processed_app_plist"
    print -u2 "Widget: $processed_widget_plist"
    exit 1
fi

processed_app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$processed_app_plist")"
processed_widget_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$processed_widget_plist")"
processed_app_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$processed_app_plist")"
processed_widget_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$processed_widget_plist")"

print "Processed app Info.plist: $processed_app_plist -> CFBundleShortVersionString=$processed_app_version CFBundleVersion=$processed_app_build"
print "Processed widget Info.plist: $processed_widget_plist -> CFBundleShortVersionString=$processed_widget_version CFBundleVersion=$processed_widget_build"

if [[ "$processed_app_version" != "$app_version" || "$processed_widget_version" != "$widget_version" || "$processed_app_version" != "$processed_widget_version" ]]; then
    print -u2 "Processed plist short-version assertion failed: app=$processed_app_version widget=$processed_widget_version expected app=$app_version widget=$widget_version"
    exit 1
fi
if [[ "$processed_app_build" != "$app_build" || "$processed_widget_build" != "$widget_build" || "$processed_app_build" != "$processed_widget_build" ]]; then
    print -u2 "Processed plist build-number assertion failed: app=$processed_app_build widget=$processed_widget_build expected app=$app_build widget=$widget_build"
    exit 1
fi
print "Processed plist parity passed: short version=$processed_app_version build number=$processed_app_build"

widget_source_plist="$project_root/LockScreenWidget/Widget/Info.plist"
widget_source_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$widget_source_plist")"
widget_source_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$widget_source_plist")"
if [[ "$widget_source_version" != '$(MARKETING_VERSION)' || "$widget_source_build" != '$(CURRENT_PROJECT_VERSION)' ]]; then
    print -u2 "Widget source substitution assertion failed: CFBundleShortVersionString=$widget_source_version (expected \$(MARKETING_VERSION)); CFBundleVersion=$widget_source_build (expected \$(CURRENT_PROJECT_VERSION))"
    exit 1
fi
print "Widget source substitution passed: CFBundleShortVersionString=\$(MARKETING_VERSION) CFBundleVersion=\$(CURRENT_PROJECT_VERSION)"

privacy_manifest_count="$(find "$app_bundle" -type f -name 'PrivacyInfo.xcprivacy' -print | wc -l | tr -d '[:space:]')"
privacy_manifest="$app_bundle/PrivacyInfo.xcprivacy"
if [[ "$privacy_manifest_count" != "1" || ! -f "$privacy_manifest" ]]; then
    print -u2 "Privacy manifest assertion failed: expected exactly one app-bundle-root PrivacyInfo.xcprivacy, found $privacy_manifest_count"
    exit 1
fi
if ! /usr/bin/python3 - "$privacy_manifest" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    manifest = plistlib.load(handle)

if set(manifest) != {"NSPrivacyAccessedAPITypes"}:
    raise ValueError("unexpected top-level privacy keys")

entries = manifest["NSPrivacyAccessedAPITypes"]
if len(entries) != 1:
    raise ValueError("expected exactly one accessed API entry")

entry = entries[0]
if set(entry) != {"NSPrivacyAccessedAPIType", "NSPrivacyAccessedAPITypeReasons"}:
    raise ValueError("unexpected accessed API keys")
if entry["NSPrivacyAccessedAPIType"] != "NSPrivacyAccessedAPICategoryUserDefaults":
    raise ValueError("expected UserDefaults accessed API category")
if entry["NSPrivacyAccessedAPITypeReasons"] != ["CA92.1"]:
    raise ValueError("expected only UserDefaults reason CA92.1")
PY
then
    print -u2 "Privacy manifest assertion failed: expected only UserDefaults reason CA92.1 and no tracking or collected-data declarations"
    exit 1
fi
print "Privacy manifest assertion passed: $privacy_manifest -> UserDefaults/CA92.1 (one root manifest)"
