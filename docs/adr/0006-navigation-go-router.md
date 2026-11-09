# ADR-0006: Navigation is go\_router with a stateful shell

**Status:** Accepted, provisional on checking the current go\_router API.

**Context:** Three tabs that should keep their own stack and scroll position, contextual detail screens, and many modal sheets.

**Drivers:** preserved tab state, correct back behaviour, declarative routes, no codegen, maintained by the Flutter team.

**Alternatives:** Plain Navigator with nested navigators (workable, tab state is manual). auto\_route (extra codegen). Hand-rolled Router API (too much code).

**Decision:** go\_router with `StatefulShellRoute` for Home, Inbox, Stores. Detail screens (store, list, wishlist, archives, settings) are routes with plain string path constants. Bottom sheets and dialogs are not routes: they use `showModalBottomSheet` and `showDialog`.

**Consequences:** Back button, predictive back on Android and iOS swipe-back follow standard route behaviour. No deep links in v1.

**Trade-offs:** string paths are not type-safe; acceptable at this size.

**Reconsider if:** deep links or a larger route tree are added.
