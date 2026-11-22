#!/usr/bin/env bash
# Single quality gate for local agents, humans, and CI (APP-005).
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

echo "==> flutter test"
flutter test
