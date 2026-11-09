# ADR-0004: Item ordering and Undo

**Status:** Accepted.

**Context:** Manual order must persist; purchased items must return to their original place; removal must be undoable with original order.

**Drivers:** simplest model that makes the three guarantees hold by construction, small lists, easy backup.

**Alternatives:** Fractional indexing or LexoRank strings (avoid renumbering writes, which only matter for very large lists, at the cost of opaque keys and rebalancing). Separate position per section (uncheck then needs its original place remembered). Soft delete with `deleted_at` (trivial Undo, but every query and the backup must filter deleted rows). Persisted undo stack (over-built).

**Decision:** Dense integer `position` in one sequence per list covering all items; purchase is a flag only. Reorder renumbers densely under D-06. Removal is a hard delete with an in-memory snapshot for Undo (D-07). Order by `(position, created_at, id)` to tolerate ties.

**Consequences:** Uncheck, carry-forward and Undo need no ordering code. Lists of hundreds of items renumber in one transaction without noticeable cost.

**Trade-offs:** a reorder writes several rows; Undo is lost on app restart.

**Reconsider if:** lists routinely exceed thousands of items, or Undo must survive restarts.
