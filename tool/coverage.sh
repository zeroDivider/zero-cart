#!/usr/bin/env bash
# Collect line coverage for local review and CI upload.
# Tracked, not enforced — see docs/testing-strategy.md.
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p coverage

echo "==> flutter test --coverage"
flutter test --coverage --reporter compact

RAW="coverage/lcov.info"
FILTERED="coverage/lcov.filtered.info"

if [[ ! -f "$RAW" ]]; then
  echo "error: expected $RAW after flutter test --coverage" >&2
  exit 1
fi

echo "==> filter generated files (*.g.dart, l10n/generated)"
dart run tool/filter_lcov.dart "$RAW" "$FILTERED"
