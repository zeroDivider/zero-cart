# ADR-0002: Local persistence is Drift (SQLite)

**Status:** Accepted (provisional on package version verification).

**Context:** Relational data with parents and children, atomic multi-row operations (assign, finish, restore), reactive reads, ordering, and migrations that must not lose user data.

**Drivers:** real foreign keys and transactions, streams, type-safe queries, testable in memory, straightforward export to JSON.

**Alternatives:** sqflite (no typed queries or reactive streams, hand-written plumbing). Isar and Hive (object stores without relational integrity; Isar's maintenance status should be re-checked before relying on it, and I have not verified it here). ObjectBox (relations exist but a heavier commercial-flavoured stack). Plain JSON file (no transactions, whole-file rewrites). Drift (closest to Room: typed SQL, migrations, streams).

**Decision:** Drift with SQLite, foreign keys enforced, stepwise migrations with committed schema snapshots.

**Consequences:** build\_runner is required; the schema and invariants live in SQL constraints as well as Dart. Tests use in-memory databases. Backup maps row-for-row.

**Trade-offs:** codegen friction and SQLite knowledge needed, in exchange for integrity and testability.

**Reconsider if:** a platform target appears that Drift does not support, or the package becomes unmaintained.
