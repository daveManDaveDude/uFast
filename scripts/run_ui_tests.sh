#!/usr/bin/env zsh

# Run the full UI suite with explicit, stable evidence paths. Keep the command
# exit code separate from all post-run reporting so a successful xcodebuild
# cannot be misclassified by wrapper cleanup.

set -e -u -o pipefail

project_name="${PROJECT:-uFast.xcodeproj}"
scheme_name="${SCHEME:-uFast}"
derived_data="${DERIVED_DATA:-.derived-data}"
simulator="${SIMULATOR:-platform=iOS Simulator,name=iPhone 17 Pro}"
worker_count="${UI_TEST_WORKERS:-4}"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild_bin="${XCODEBUILD_BIN:-xcodebuild}"
source_freeze_id="${SOURCE_FREEZE_ID:-unspecified}"

if [[ "${1:-}" == "--self-test" ]]; then
  print "UI test wrapper self-test passed"
  exit 0
fi

run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
evidence_root="${UI_RESULTS_DIR:-${derived_data}/sprint-results}"
result_bundle="${UI_RESULT_BUNDLE:-${evidence_root}/ui-${run_id}.xcresult}"
log_path="${UI_TEST_LOG:-${evidence_root}/ui-${run_id}.log}"

if [[ -e "$result_bundle" ]]; then
  print -u2 "UI result bundle already exists: $result_bundle"
  print -u2 "Choose a new UI_RESULT_BUNDLE path rather than overwriting evidence."
  exit 2
fi

mkdir -p "$(dirname "$result_bundle")" "$(dirname "$log_path")"

if [[ -n "${AGENTIC_ACTIVITY_WORKER:-}" ]]; then
  python3 scripts/agentic_activity.py update \
    --worker "$AGENTIC_ACTIVITY_WORKER" \
    --story "${AGENTIC_ACTIVITY_STORY:-unknown}" \
    --state waiting_on_tool \
    --phase integration-test \
    --active-command "xcodebuild UI test suite" \
    --expected-next-evidence "Stable UI log, xcresult bundle, and underlying exit code." \
    --waiting-on-external-tool \
    --write-scope "${AGENTIC_ACTIVITY_WRITE_SCOPE:-read-only-validation}" \
    >/dev/null 2>&1 || true
fi

command_line=(
  "$xcodebuild_bin"
  -project "$project_name"
  -scheme "$scheme_name"
  -destination "$simulator"
  -derivedDataPath "$derived_data"
  -only-testing:uFastUITests
  -parallel-testing-enabled YES
  -parallel-testing-worker-count "$worker_count"
  -enableCodeCoverage NO
  -resultBundlePath "$result_bundle"
  test
)

{
  print "command: ${(@q)command_line}"
  print "log_path: $log_path"
  print "result_bundle: $result_bundle"
  print "worker_count: $worker_count"
  print "simulator: $simulator"
  print "developer_dir: $developer_dir"
  print "source_freeze_id: $source_freeze_id"
} >"$log_path"

print "UI test evidence log: $log_path"
print "UI test result bundle: $result_bundle"

set +e
DEVELOPER_DIR="$developer_dir" "${command_line[@]}" >>"$log_path" 2>&1
exit_code=$?
set -e
print "underlying_exit_code: $exit_code" >>"$log_path"

if (( exit_code == 0 )); then
  print "UI test xcodebuild exit code: $exit_code"
else
  print -u2 "UI test xcodebuild exit code: $exit_code"
  print -u2 "Last UI test log lines:"
  tail -n 80 "$log_path" >&2
fi

final_exit_code="$exit_code"
if (( exit_code == 0 )) && [[ ! -e "$result_bundle" ]]; then
  print -u2 "UI test xcodebuild succeeded but did not produce: $result_bundle"
  print "wrapper_artifact_check: missing result bundle" >>"$log_path"
  final_exit_code=1
fi

if [[ -n "${AGENTIC_ACTIVITY_WORKER:-}" ]]; then
  activity_state="working"
  activity_phase="handoff"
  if (( final_exit_code != 0 )); then
    activity_state="errored"
    activity_phase="integration-test"
  fi
  python3 scripts/agentic_activity.py update \
    --worker "$AGENTIC_ACTIVITY_WORKER" \
    --story "${AGENTIC_ACTIVITY_STORY:-unknown}" \
    --state "$activity_state" \
    --phase "$activity_phase" \
    --artifacts-touched "$log_path" "$result_bundle" \
    --hypothesis "UI xcodebuild exit code: $exit_code" \
    --expected-next-evidence "Review $result_bundle and verify exact-once four-worker coverage." \
    --write-scope "${AGENTIC_ACTIVITY_WRITE_SCOPE:-read-only-validation}" \
    >/dev/null 2>&1 || true
fi

exit "$final_exit_code"
