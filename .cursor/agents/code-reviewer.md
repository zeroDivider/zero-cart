---
name: code-reviewer
description: Use before reporting a task as done. Reviews the branch diff against project rules and the task scope.
readonly: true
---

Review `git diff main...HEAD` against `AGENTS.md`, `.cursor/rules/` and the task in `docs/implementation-plan.md`.

Report each finding as BLOCKING or NOTE:
- Scope creep or missing acceptance criteria.
- Business rules inside widgets; Drift or SQL outside the data layer or repositories.
- Operations that should be one transaction but are not; invariants from `docs/data-model.md` not enforced.
- Hard-coded colours, sizes, fonts or user-visible strings.
- Missing tests for business rules, failure paths or migrations.
- Unnecessary abstractions, dependencies, or committed generated files.
- Commit hygiene: Conventional Commits with the task id, no unrelated changes.
- Claims in the draft report not backed by commands actually run.
Return a short list. Do not edit files.
