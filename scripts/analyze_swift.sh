#!/bin/zsh

set -euo pipefail

repository_root="${0:A:h:h}"
repository_root_without_leading_slash="${repository_root#/}"
analysis_derived_data="${repository_root}/.derived-data/swiftlint-analyze"
analysis_log_directory="${repository_root}/.derived-data/logs"
compiler_log="${analysis_log_directory}/swiftlint-analyze-xcodebuild.log"
analysis_baseline="${analysis_log_directory}/swiftlint-analyze-baseline.json"
developer_directory="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$repository_root"

./scripts/count_swift_sources.sh \
    "SwiftLint analyzer" \
    UFastCore \
    UFastCoreTests \
    uFast \
    LockScreenShared \
    LockScreenPrototype \
    LockScreenWidget \
    uFastTests \
    uFastUITests

make project
mkdir -p "$analysis_log_directory"
sed "s|__REPOSITORY_ROOT__|${repository_root_without_leading_slash}|g" \
    .swiftlint-analyze-baseline.json \
    > "$analysis_baseline"

DEVELOPER_DIR="$developer_directory" xcodebuild \
    -project uFast.xcodeproj \
    -scheme uFast \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -derivedDataPath "$analysis_derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    clean build-for-testing \
    | tee "$compiler_log"

DEVELOPER_DIR="$developer_directory" xcodebuild \
    -project uFast.xcodeproj \
    -scheme uFastLockScreenPrototypeHost \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$analysis_derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build \
    | tee -a "$compiler_log"

DEVELOPER_DIR="$developer_directory" swiftlint analyze \
    --strict \
    --baseline "$analysis_baseline" \
    --compiler-log-path "$compiler_log"
