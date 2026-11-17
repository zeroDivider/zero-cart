# ADR-0007: UI write, failure and form conventions

**Status:** Accepted

## Context

By APP-014 the screens shared one read stack (`StreamProvider` to repository to Drift) but handled writes in different ways: inbox and item sheets keep a `Notifier` with a `writeFailed` flag and show an inline error; list archive and purchase use `try/catch` and a snackbar tied to the screen's `BuildContext`; store create, edit, archive and restore have no failure handling; reorder swallows errors; Undo failures show only after the Removed snackbar closes. Store and list forms are plain `StatefulWidget`s that return a draft while inbox and item sheets write themselves. Load errors render raw `Text('$error')`. Reusable sheets sit in inconsistent places, and store details imports `stores_screen.dart` only to call `editStore`. The plan fixed the architecture but not these conventions, so each task chose its own.

## Decision drivers

One mental model for agents and for users; every failure path visible and testable; messages that survive navigation (architecture 2.5); no per-task invention; reusable forms for the draft-only flow in APP-015.

## Alternatives

- Leave as is: cheapest now, but every new feature adds a fifth variation.
- A global error Notifier or event bus: central, but over-built for a local-only app and harder to test.
- Small shared primitives plus written conventions (chosen).

## Decision

1. **Messages.** All snackbars go through `AppMessenger` (`lib/core/ui/app_messenger.dart`), backed by the root messenger key. Feature code never calls `ScaffoldMessenger.of(context)`. One snackbar at a time: a new one replaces the current. Kinds: info, error, undo, and action (an info snackbar with one named action such as Open, used by F13 and the assign flow).
2. **Writes.** Three surfaces, one helper `runWrite` that never swallows an error and never shows raw exception text:
   - *Form submit:* the sheet stays open with an inline, localised error.
   - *Direct action* (checkbox, archive, restore, reorder, remove): an error snackbar; the UI reverts (an optimistic reorder is dropped).
   - *Undo:* if the restore fails, an error snackbar replaces the Removed snackbar immediately.
   Typed repository errors (list unavailable, store archived, stale order) map to specific messages via `messageFor(l10n, error)`; anything else maps to one generic message. Callers capture `l10n` before awaiting.
3. **Forms.** One `FormSheetScaffold` (`lib/core/widgets/`) owns the submitting and inline-error state, disables actions while submitting and closes on success. The sheet performs the write through the callback it is given. In draft mode the callback only returns a draft and writes nothing (assignment flow, APP-015). No per-sheet `Notifier` for submit state.
4. **Reads.** One `AsyncBody` widget renders loading, error (localised message plus Retry) and data. No `Text('$error')`.
5. **UI state placement.** Local, ephemeral widget state (field values, submitting flag, segmented selection) is `StatefulWidget` state. State shared across widgets or surviving rebuilds and navigation (multi-select, purchased-section expansion) is a Riverpod `Notifier`. This refines architecture 2.2.
6. **Placement and imports.** Reusable sheets live in `<feature>/ui/sheets/` together with their `show...Sheet` entry function. A feature may import another feature's `ui/sheets/`, never its screens. Entry functions never live in screens.
7. **State-change matrix.**

| Action | Behaviour |
|---|---|
| Remove item, Inbox item, wishlist item | Hard delete, Undo snackbar, no dialog (D-07) |
| Archive list | Immediate, Undo snackbar (APP-017) |
| Archive store | Dialog only when active lists exist, otherwise immediate; restore from Archive |
| Replace-all restore | Confirmation dialog |
| Purchase toggle, reorder, restore store or list | Immediate, no dialog |

## Enforcement

Guard tests fail on `ScaffoldMessenger.of(` outside `lib/core/ui/` and on raw error interpolation such as `Text('$error')` in `lib/features/`. The `code-reviewer` subagent checks every task against this ADR. Every task from APP-015 on tests its failure path with a fake that throws.

## Consequences and trade-offs

Four small shared widgets and helpers to maintain; a migration cost (APP-014a to 014c). In exchange, every write has one visible failure behaviour and new features copy a pattern instead of inventing one.

## Reconsider if

A second platform surface appears (desktop, widgets), or the number of form types makes a form-state library worthwhile.

## Amendment (APP-014c)

Approved during APP-014c migration:

1. **`FormSheetScaffold` extensions.** The scaffold may take an optional `secondaryAction` (a second submit path such as Quick-add “Add another”, or a custom button such as Remove) and per-path `popOnSuccess`. Primary submit still defaults to closing on success. Secondary submit with `popOnSuccess: false` keeps the sheet open, clears submitting state, and may run an `onKeepOpenSuccess` callback (clear fields and restore focus). On failure the sheet stays open with the inline `messageFor` error and input is kept.
2. **Inline non-sheet fields.** Rows that are not modal sheets (for example the list add-item row) follow the same inline-error rule without a shared abstraction: local `StatefulWidget` state owns submitting and the error string, mapped with `messageFor`. Success clears the field, keeps focus, and may set a scroll target; failure keeps the text, shows the inline error, and keeps focus.

## Amendment (APP-015)

Owner confirmed 2026-11-16: from APP-015 onward, tasks follow the APP-014 / 014a–c conventions in this ADR without re-litigating them — sheets under `<feature>/ui/sheets/`, FormSheetScaffold inline errors on sheet Confirm (including assign), `runWrite` + snackbar only for direct actions. Plan Component paths that still say `ui/foo_sheet.dart` mean `ui/sheets/foo_sheet.dart`.
