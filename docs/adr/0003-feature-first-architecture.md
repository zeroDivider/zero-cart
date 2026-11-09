# ADR-0003: Feature-first architecture without a domain layer

**Status:** Accepted.

**Context:** Small app, single local data source, no shared rules across sources, one developer plus coding agents.

**Drivers:** minimal indirection, rules in one findable place, agent-friendly consistency.

**Alternatives:** Clean Architecture with entities, use cases and repository interfaces (maps to your modular background but adds mapping and interface layers with nothing to swap). Layer-first folders (spreads one feature across the tree). Multi-package modules (build and tooling cost with no team-scale benefit).

**Decision:** Feature-first folders; repositories own business rules and transactions; pure helpers in `core/`; Drift rows are the models; no repository interfaces.

**Consequences:** UI depends on Drift row types. Tests use real in-memory Drift instead of mocks, which exercises the actual SQL.

**Trade-offs:** swapping the database later would touch more files; accepted.

**Reconsider if:** a second data source (sync) or a rule shared by several features appears.
