# ADR-0005: Backup and restore

**Status:** Accepted.

**Context:** Data ownership with no cloud. Restore must be safe, portable across Android and iOS, and survive app and schema evolution.

**Drivers:** no data loss on failure, human-inspectable file, versioning, no extra permissions.

**Alternatives:** Copying the SQLite file (binary, tied to the database schema version, hard to validate, platform paths). Merge-on-import (conflict rules out of scope for v1). Cloud backup (excluded). JSON with generated serializers (adds codegen for a flat format).

**Decision:** Versioned JSON mirroring the tables, hand-written mapping, validate fully in memory before touching the database, replace-all in one transaction, export through share\_plus, import through file\_picker. Settings are included.

**Consequences:** A new table or column requires updating the exporter, validator and upgraders and adding a round-trip test. The backup version is independent of the database version.

**Trade-offs:** hand-written mapping is more code than generated serialisation but keeps validation explicit. Replace-all can discard newer local data; mitigated by the 'Export current data first' option.

**Reconsider if:** merging across devices is wanted.
