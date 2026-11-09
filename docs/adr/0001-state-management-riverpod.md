# ADR-0001: State management is Riverpod

**Status:** Accepted (provisional on a version check of the current Riverpod API).

**Context:** Data is a local relational database exposed as reactive streams. UI state is small: selection, drafts, expanded sections. Business operations are transactional methods. Undo is a one-shot action with a snapshot.

**Drivers:** native stream support, dependency injection, testability with an in-memory database, low ceremony for AI-written code, one consistent pattern.

**Alternatives:** BLoC (explicit events and states; each interaction costs an event class, a handler and a state field, and Undo becomes either state in the bloc or a BlocListener side effect). Cubit (less ceremony, but no dependency injection, so a second mechanism such as provider or get\_it is needed anyway). Riverpod (streams, injection and overrides in one tool).

**Decision:** Riverpod 'by hand', without code generation. DB reads are `StreamProvider`s; UI-only state is a `Notifier`; repositories are plain classes exposed through providers.

**Representative operation, remove with Undo (pseudocode):**

```
# Riverpod
listItemsProvider.family(listId) = StreamProvider(repo.watchItems(listId))
on swipe: snapshot = await repo.removeItem(id)
          messenger.showSnackBar(action: Undo -> repo.restoreItem(snapshot))

# BLoC
event RemoveItemRequested(id) -> handler: snapshot = await repo.removeItem(id)
                                          emit(state.copyWith(pendingUndo: snapshot))
BlocListener: shows snackbar when pendingUndo != null, Undo adds RestoreItemRequested(snapshot),
              handler clears pendingUndo
```

**Consequences:** Android mapping: StreamProvider is like collecting a Flow, a Notifier is a lightweight ViewModel without lifecycle ownership, overrides replace Hilt test modules. Convention: never `ref.read` inside `build`, repository providers are app-lifetime, widgets never hold business rules.

**Trade-offs:** less enforced structure than BLoC; discipline rests on AGENTS.md rules and review. Riverpod's API has changed between major versions, so agents must check current docs and not rely on older snippets.

**Reconsider if:** provider count passes \~60, or flows need event replay or complex concurrency semantics.
