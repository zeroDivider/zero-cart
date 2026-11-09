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

Splitting rules: drop the top-level pack title, the intro paragraphs before the first numbered section, the path headings (for example `## 1. docs/decisions-and-assumptions.md`, `## 4. docs/adr/`) and the `---` rules between sections. Give each file a single `#` title derived from its filename (`decisions-and-assumptions.md` → `# Decisions and assumptions`, `architecture.md` → `# Architecture`, `data-model.md` → `# Data model`, `product-requirements.md` → `# Product requirements`, `user-flows.md` → `# User flows`, `design-system.md` → `# Design system`). Promote body headings by one level (`###` → `##`); keep their section numbers (1.1, 2.3, 3.12) unchanged. ADR files: `### ADR-000N: ...` becomes `# ADR-000N: ...` (keep the heading text), one file per ADR, no extra title. Part 3 → `docs/implementation-plan.md`: change only the first line to `# Implementation plan`; keep everything else, including the intro paragraph. Do not otherwise edit content (no rewording, no cross-reference fixes). Part 1 section numbers (for example 'section 3.4', '2.5') keep their numbers inside the split files; when a document says 'Part 1, section 3.4' it means `docs/data-model.md` section 3.4.

The Claude documents can be exported as Markdown from the document's menu in Claude.
