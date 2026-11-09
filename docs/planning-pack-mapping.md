# Planning pack: source documents and repository files

The planning documents were written in Claude as three documents. This file says which section becomes which repository file. Cross-references in the text such as 'Part 1', 'Part 2a', 'Part 4' refer to the sources below; resolve them with this table.

| Source | Section (heading) | Repository file |
|---|---|---|
| Part 1: Decisions, Architecture, Data Model, ADRs | '1. docs/decisions-and-assumptions.md' | `docs/decisions-and-assumptions.md` |
| Part 1 | '2. docs/architecture.md' | `docs/architecture.md` |
| Part 1 | '3. docs/data-model.md' | `docs/data-model.md` |
| Part 1 | '4. docs/adr/', ADR-0001 | `docs/adr/0001-state-management-riverpod.md` |
| Part 1 | ADR-0002 | `docs/adr/0002-persistence-drift.md` |
| Part 1 | ADR-0003 | `docs/adr/0003-feature-first-architecture.md` |
| Part 1 | ADR-0004 | `docs/adr/0004-item-ordering-and-undo.md` |
| Part 1 | ADR-0005 | `docs/adr/0005-backup-and-restore.md` |
| Part 1 | ADR-0006 | `docs/adr/0006-navigation-go-router.md` |
| Part 2a: Requirements, User Flows, Design System | '1. docs/product-requirements.md' | `docs/product-requirements.md` |
| Part 2a | '2. docs/user-flows.md' | `docs/user-flows.md` |
| Part 2a | '3. docs/design-system.md' | `docs/design-system.md` |
| Part 3: Implementation Plan | whole document | `docs/implementation-plan.md` |
| Part 4 (this bundle) | files as delivered | repository root, `.cursor/`, `docs/`, `design/` |

Splitting rules: drop the heading line that only names the file path; keep the rest unchanged; promote the remaining headings by one level so each file starts with a single `#` title; do not otherwise edit content. Part 1 section numbers (for example 'section 3.4', '2.5') keep their numbers inside the split files; when a document says 'Part 1, section 3.4' it means `docs/data-model.md` section 3.4.

The Claude documents can be exported as Markdown from the document's menu in Claude.
