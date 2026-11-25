#!/usr/bin/env bash
# Single quality gate for local agents, humans, and CI (APP-005).
# Always collects coverage and writes coverage/lcov.filtered.info.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart pub get"
dart pub get

echo "==> flutter gen-l10n"
flutter gen-l10n

echo "==> dart run build_runner build"
dart run build_runner build

echo "==> dart format --output=none --set-exit-if-changed ."
dart format --output=none --set-exit-if-changed .

echo "==> flutter analyze"
flutter analyze

mkdir -p coverage
echo "==> flutter test --coverage --reporter compact"
flutter test --coverage --reporter compact

RAW="coverage/lcov.info"
FILTERED="coverage/lcov.filtered.info"
if [[ ! -f "$RAW" ]]; then
  echo "error: expected $RAW after flutter test --coverage" >&2
  exit 1
fi
echo "==> filter generated files (*.g.dart, l10n/generated)"
dart run tool/filter_lcov.dart "$RAW" "$FILTERED"
