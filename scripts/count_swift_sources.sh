#!/bin/zsh

set -euo pipefail

if (( $# < 2 )); then
    print -u2 "usage: $0 <label> <source-root>..."
    exit 64
fi

label="$1"
shift

source_count=$(find "$@" -type f -name '*.swift' -print | LC_ALL=C sort -u | wc -l | tr -d ' ')
print "${label} Swift source count: ${source_count}"
