#!/bin/zsh

set -euo pipefail

production_files=(
    project.yml
    uFast
    scripts/testflight-export-options.plist
)

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

if [[ -e uFast/SupportingFiles/uFast.entitlements ]]; then
    print -u2 "The local-only release must not include an entitlement file."
    exit 1
fi

print "Local-only release configuration verified."
