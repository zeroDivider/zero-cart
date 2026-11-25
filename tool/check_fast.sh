#!/usr/bin/env bash
# Fast intermediate check: format + analyze + targeted tests.
# Usage: tool/check_fast.sh [test/path/to/feature]
# Skips pub get, gen-l10n, and build_runner. Use tool/check.sh for the full gate.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart format --output=none --set-exit-if-changed ."
dart format --output=none --set-exit-if-changed .

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test ${1:-} --reporter compact"
flutter test ${1:-} --reporter compact
