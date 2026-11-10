#!/usr/bin/env bash
# Single quality gate for local agents, humans, and CI (APP-005).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart pub get"
dart pub get

# Code generation: gen-l10n now; build_runner once Drift exists (APP-006).
echo "==> flutter gen-l10n"
flutter gen-l10n

echo "==> dart format --output=none --set-exit-if-changed ."
dart format --output=none --set-exit-if-changed .

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test
