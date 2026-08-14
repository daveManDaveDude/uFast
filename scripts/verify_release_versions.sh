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

show_build_setting() {
    local target="$1"
    DEVELOPER_DIR="$developer_dir" xcodebuild \
        -project "$project_file" \
        -target "$target" \
        -configuration Release \
        -showBuildSettings 2>/dev/null \
        | awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }'
}

app_version="$(show_build_setting uFast)"
widget_version="$(show_build_setting uFastLockScreenWidget)"

if [[ -z "$app_version" || -z "$widget_version" ]]; then
    print -u2 "Could not resolve MARKETING_VERSION for the app and widget targets."
    exit 1
fi

if [[ "$app_version" != "$widget_version" ]]; then
    print -u2 "Release short-version mismatch: app=$app_version widget=$widget_version"
    exit 1
fi

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

processed_app_plist="$verification_derived_data/Build/Products/Release-iphonesimulator/uFast.app/Info.plist"
processed_widget_plist="$verification_derived_data/Build/Products/Release-iphonesimulator/uFast.app/PlugIns/uFast Lock Screen Widget.appex/Info.plist"

if [[ ! -f "$processed_app_plist" || ! -f "$processed_widget_plist" ]]; then
    print -u2 "Release build did not produce both processed Info.plists."
    print -u2 "App: $processed_app_plist"
    print -u2 "Widget: $processed_widget_plist"
    exit 1
fi

processed_app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$processed_app_plist")"
processed_widget_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$processed_widget_plist")"

if [[ "$processed_app_version" != "$app_version" || "$processed_widget_version" != "$widget_version" ]]; then
    print -u2 "Processed short-version mismatch: app=$processed_app_version widget=$processed_widget_version expected=$app_version"
    exit 1
fi

print "Processed app Info.plist: $processed_app_plist -> $processed_app_version"
print "Processed widget Info.plist: $processed_widget_plist -> $processed_widget_version"

widget_source_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$project_root/LockScreenWidget/Widget/Info.plist")"
if [[ "$widget_source_version" != '$(MARKETING_VERSION)' ]]; then
    print -u2 "Widget source plist must derive CFBundleShortVersionString from MARKETING_VERSION."
    exit 1
fi

print "Release short-version assertion passed: app=$app_version widget=$widget_version"
