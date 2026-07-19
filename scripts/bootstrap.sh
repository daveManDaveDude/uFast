#!/bin/zsh
set -euo pipefail

required_formulae=(xcodegen swiftlint swiftformat)
missing_formulae=()

if [[ ! -d /Applications/Xcode.app ]]; then
  print -u2 "Xcode is required. Install it from the Mac App Store, then rerun this script."
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  print -u2 "Homebrew is required. Install it from https://brew.sh, then rerun this script."
  exit 1
fi

for formula in "${required_formulae[@]}"; do
  if ! brew list --versions "$formula" >/dev/null 2>&1; then
    missing_formulae+=("$formula")
  fi
done

if (( ${#missing_formulae[@]} > 0 )); then
  brew install "${missing_formulae[@]}"
fi

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild -version
xcodegen generate

print
print "uFast setup is ready."
print "Run 'make build' for a simulator build and 'make test' for all tests."

