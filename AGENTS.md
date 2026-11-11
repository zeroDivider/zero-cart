# AGENTS.md - ZeroCart

ZeroCart (repository `zero-cart`, Dart package `zero_cart`) is an offline-first Flutter shopping-list app for Android and iOS. You are an implementation agent. Product rules, architecture and tasks are already decided. Do not redesign them.

## Authoritative documents (read before coding)

- Tasks: `docs/implementation-plan.md` (do exactly the task you are given)
- Product: `docs/product-requirements.md`, `docs/user-flows.md`, `docs/decisions-and-assumptions.md` (D-xx ids)
- Architecture: `docs/architecture.md`, `docs/adr/`
- Data: `docs/data-model.md`, `docs/backup-format.md`
- UI: `docs/design-system.md` and `design/shopping-app-prototype.html` (layout reference; tokens in the design system win)
- Process and quality: `docs/ai-development-workflow.md`, `docs/testing-strategy.md`
- Cross-references such as "Part 1" or "Part 2a" are resolved by `docs/planning-pack-mapping.md`

These are authoritative but not immutable. If a change is needed, stop, explain it, and record it in `docs/deviations.md`. Never change a business rule silently.

## Workflow: Analyze, Plan, Implement, Verify, Document

1. Start clean: `git status` must be empty. Then `git switch main && git switch -c task/APP-0NN-short-slug`.
2. Analyze: read the task, the requirement and decision ids it cites, the ADRs and the existing code. Run the `spec-checker` subagent.
3. Plan: state in at most 10 lines what you will change and which tests you will add.
4. Implement in small steps and commit after each step (see Commits).
5. Verify: run `tool/check.sh` (before APP-005 exists: `dart format`, `flutter analyze`, `flutter test`). Use the `verifier` subagent for long output. Fix failures; never weaken or delete a test to pass.
6. Review: run the `code-reviewer` subagent on `git diff main...HEAD`. Fix blocking findings.
7. Document: update only the docs the task lists. Log deviations.
8. Report with the template in `docs/ai-development-workflow.md`. Stop at review gates (APP-008, APP-014, APP-022, APP-027).

## Commits: every step is committed

- One branch per task. Commit after every coherent step. Never stop or hand over with uncommitted work.
- Conventional Commits with the task id: `feat(lists): add reorderActive operation [APP-013]`. Types: feat, fix, test, refactor, docs, chore, build, ci. Imperative subject, at most 72 characters.
- Body: what and why in a short paragraph. Last line: `Assisted-by: Cursor Agent (Auto)`.
- Every commit passes format and analysis. Add tests together with the code they cover. Do not commit a red test suite.
- Never commit generated files (`*.g.dart`, gen-l10n output), build output, secrets, keystores, `.env` files or IDE files. Drift schema snapshots in `drift_schemas/` are committed.
- Never amend, rebase, force-push, push, tag or merge into main. The owner reviews and merges.
- Never mix two tasks on one branch.

## Conventions

- Layers: `ui -> providers/controllers -> repositories -> Drift`. Business rules and transactions live only in repositories. Pure logic lives in `lib/core/`. No SQL or Drift queries in widgets.
- State: Riverpod only (ADR-0001), hand-written providers, no codegen. No other state or DI library. Repository providers are app-lifetime.
- Persistence: Drift. Every multi-row operation runs in one transaction. A schema change needs a version bump, a migration, an updated snapshot and a migration test.
- UI: colours, sizes and fonts only from `lib/app/theme/`. Strings only through gen-l10n (`app_en.arb` now, Serbian in APP-024). 48dp touch targets, 200% text scale, semantics for every gesture.
- Dependencies: add one only when the task needs it. Check its current version, changelog and API on pub.dev first. Report the version. Never invent an API or a version.
- Simplicity: no abstraction without a current need, no interface for a single implementation, no speculative features (v2 items are out of scope).
- Tests: real in-memory Drift for data behaviour, fakes over mocks, every business rule has a test.

## Hard stops: ask the owner instead of guessing

- A business rule is ambiguous or two documents disagree.
- You cannot confirm a package API in current documentation.
- The work needs scope beyond the task.
- A check still fails after 3 genuine attempts.
- Anything security-sensitive: permissions, file access, network, signing.

## Honesty

Never claim a command ran or a test passed unless you ran it in this session. In every report, list what you could not verify.

## Context budget
- Read only your task's section in docs/implementation-plan.md (search "### APP-0NN") and only the requirement, decision and ADR sections it cites. Never open whole documents.
- Read targeted files; do not re-read files you just wrote.
- Run tests with compact output (flutter test --reporter compact). Let the verifier subagent run analyze, build_runner and long suites; never paste long logs into the chat.
- If a task needs more than about 15 changed files, or the context is getting large, stop at the next clean commit, report what remains, and propose splitting the task.
- Keep reports short.

## Auto model note

The model may change between tasks and even within one. Rely on the repository documents, not on chat history. Start every task in a fresh chat.
