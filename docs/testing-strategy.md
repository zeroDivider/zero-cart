# Testing and quality strategy

## 1. Principles

- Test behaviour and rules, not framework wiring. The highest risks are ordering, purchase transitions, Undo, assignment, wishlist copying, finish and carry-forward, store archiving, backup restore and migrations.
- Use real implementations where cheap (in-memory Drift), fakes at platform edges, mocks only when a fake is impractical.
- A test that cannot fail is not a test: a business rule's test must fail if the rule is removed.

## 2. Test types

| Type | Tool | Scope |
|---|---|---|
| Unit | `flutter_test` | Pure logic in `lib/core/` (dense reorder, share text, normalisation), backup validator, locale resolution |
| Database | `flutter_test` + in-memory Drift | Constraints, foreign keys, cascades, every operation in `docs/data-model.md` 3.5, rollback on failure |
| Repository/state | `flutter_test` + `ProviderContainer` | Streams update after writes; typed errors; Undo snapshots |
| Widget | `flutter_test` | Screens and sheets with provider overrides; interactions (add, check, drag, swipe, Undo); both locales; text scale 200% |
| Golden | `flutter_test` `matchesGoldenFile` | A few high-value visuals (item row states, Home board, forms) in light and dark; tagged `golden`, CI platform only |
| Integration | `integration_test` | Journeys: capture, assign, shop, reorder, finish with carry-forward; backup export then restore |
| Migration | Drift schema tooling | Every historical schema version upgrades to the current one with data preserved |
| Accessibility | guideline matchers + manual | Tap target size, labelled targets, contrast; TalkBack/VoiceOver checklist |

## 3. Mocks, fakes and real databases

- **Real in-memory Drift** for anything that touches tables. This exercises the actual SQL, constraints and transactions.
- **Fakes:** `ShareService`, file picker, clock (`nowProvider`), id generator (predictable ids). Fakes are small hand-written classes in `test/support/`.
- **Mocks (mocktail):** only for an object that cannot be faked simply. Expected to be rare.
- Never mock the database or a repository when testing a screen's data behaviour; override the provider with a real repository over an in-memory database.

## 4. Priority test list

1. **Ordering:** dense reorder with purchased items in the middle, ties, stale input; purchase then reorder then unpurchase returns the item to its stored slot.
2. **Undo:** restore with the original position, after other reorders, with a position tie, into an archived list (typed failure), after navigation.
3. **Purchase transitions:** flag only, position untouched, sections update.
4. **Inbox assignment:** single and batch, new store and list in one transaction, rollback leaves Inbox and tables untouched, oldest-first order, archived targets rejected.
5. **Wishlist copy:** copies are independent, entry preserved, new list created atomically.
6. **Finish and carry-forward:** order preserved, purchased reset, original unchanged, atomic failure, empty and no-leftover cases, restore guard for archived stores.
7. **Store archive and restore:** lists untouched, hidden everywhere, dialog only with active lists.
8. **Backup:** fixture-exact export, every validation error class, round-trip equality, rollback on injected failure.
9. **Migrations:** each step with representative data.
10. **Share text:** exact format, empty case, special characters.
11. **Localisation:** plural forms for 1, 2, 5, 11, 12, 21, 22, 25 in Serbian; key screens in both locales.

## 5. Quality gates

Every task must pass, locally and in CI:
1. `dart format --output=none --set-exit-if-changed .`
2. `flutter analyze` with zero issues (strict-casts, strict-inference, strict-raw-types).
3. `flutter test` (excluding integration tests) green.
4. Code generation succeeds from a clean checkout (`build_runner`, gen-l10n).
5. Dependency check: every added package is verified on pub.dev and reported; `pubspec.lock` committed; no unused dependencies.
6. Hard-coded colour and string checks (scripted in `tool/check.sh` from APP-003 and APP-024).
7. Docs listed by the task are updated; deviations logged.

Coverage is tracked, not enforced; the priority list above matters more than a percentage. Locally run `bash tool/coverage.sh` (`flutter test --coverage`, then `dart run tool/filter_lcov.dart` to drop `*.g.dart` and `l10n/generated` into `coverage/lcov.filtered.info` and print a line summary). Optional HTML: `genhtml coverage/lcov.filtered.info -o coverage/html`. CI uploads the filtered report to Codecov with `fail_ci_if_error: false` so a missing `CODECOV_TOKEN` does not fail the gate.

## 6. GitHub Actions setup

One workflow, `.github/workflows/ci.yml`, triggered on pull requests and pushes to `main`:
- Job `check` on `ubuntu-latest`: checkout, set up the pinned Flutter version (check the setup action's current documentation), cache pub, run `tool/check.sh`, then `tool/coverage.sh` and a non-blocking Codecov upload.
- No matrix, no deployment, no signing. The only optional secret is `CODECOV_TOKEN` for coverage upload; the quality gate does not require it. Add an Android build job only when release work starts (APP-027).
- Integration tests run locally on an emulator or simulator until a stable CI setup is worth the effort.
`tool/check.sh` is the single source of the quality-gate steps so humans, agents and CI run the same gate.

## 7. Accessibility verification

Automated: guideline matchers in widget tests (tap target, labelled target, text contrast) in both themes; 200% text scale tests for every screen. Manual: `docs/accessibility-checklist.md` (created in APP-025) run with TalkBack on Android and VoiceOver on iOS; record results and what was not covered.
