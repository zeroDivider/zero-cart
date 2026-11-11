# Deviations and open questions

Record every departure from the planning documents here, and every question that needed the owner. One row per item.

| Date | Task | Document and section | What differs | Reason | Decision (owner) |
|---|---|---|---|---|---|
| 2026-11-09 | APP-001 | `docs/implementation-plan.md` APP-001 | Bundle id is `com.zero.cart` instead of placeholder `com.example.zerocart`. | Owner chose the shipping reverse-DNS id now to avoid a pre-release rename. Plan text updated in the same task. | Approved: use `com.zero.cart`. |
| 2026-11-10 | APP-005 | `docs/testing-strategy.md` §5.6 | Hard-coded colour check stays a unit test under `flutter test`, not a separate shell grep in `tool/check.sh`. | APP-003 acceptance requires a failing test; APP-005 does not list a colour shell step. String hard-coding checks remain APP-024. | Approved: keep unit test; shell string checks in APP-024. |
| 2026-11-10 | APP-005 | `docs/testing-strategy.md` §6 | CI job runs only `tool/check.sh`; no separate golden-test step yet. | Goldens do not exist until APP-026; APP-005 says the workflow runs the same script. | Approved: defer golden CI step to APP-026. |
| 2026-11-10 | APP-006 | `docs/data-model.md` §3.2 vs D-08 / `docs/backup-format.md` | `inbox_items` and `wishlist_items` have no SQL length CHECKs; `list_items` does (title 1..50, description null\|1..70). | Task requires tables from §3.2 exactly; §3.2 omits length CHECKs on inbox/wishlist while D-08 and backup validation still use 50/70. Enforced in app/restore later. | Pending owner: keep as-is, or add the same SQL CHECKs as list items. |
| 2026-11-11 | APP-009 | `docs/data-model.md` §3.2 / plan APP-009 vs prototype `free()` | When every palette key is used by an active store, `nextFreeColorKey` returns `palette[activeCount % 8]` (cycle). Prototype falls back to `sky`. | Plan and data model say "else cycle"; prototype is layout-only. | Approved: cycle by `activeCount % 8`; not sky. Docs clarified in the same change. |
