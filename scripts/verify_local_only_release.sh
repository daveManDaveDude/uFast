#!/bin/zsh

set -euo pipefail

production_files=(
    project.yml
    uFast
    scripts/testflight-export-options.plist
)

project_root="${0:A:h:h}"
cd "$project_root"

forbidden_references=$(rg -n -i 'cloudkit|icloud|ubiquity|remote-notification' "${production_files[@]}" || true)
if print -r -- "$forbidden_references" | rg -v 'cloudKitDatabase: \.none' | rg -q '.'; then
    print -r -- "$forbidden_references"
    print -u2 "Release configuration contains a forbidden cloud or remote-notification reference."
    exit 1
fi

if ! rg -n 'cloudKitDatabase: \.none' uFast/Persistence/PersistenceContainer.swift >/dev/null; then
    print -u2 "PersistenceContainer must explicitly disable CloudKit."
    exit 1
fi

python3 scripts/verify_entitlements.py

if [[ -n "${BUILT_APP_ENTITLEMENTS:-}" || -n "${BUILT_WIDGET_ENTITLEMENTS:-}" ]]; then
    if [[ -z "${BUILT_APP_ENTITLEMENTS:-}" || -z "${BUILT_WIDGET_ENTITLEMENTS:-}" ]]; then
        print -u2 "BUILT_APP_ENTITLEMENTS and BUILT_WIDGET_ENTITLEMENTS must be supplied together."
        exit 1
    fi
    python3 scripts/verify_entitlements.py \
        --built-app "$BUILT_APP_ENTITLEMENTS" \
        --built-widget "$BUILT_WIDGET_ENTITLEMENTS"
fi

print "Local-only release configuration verified."
