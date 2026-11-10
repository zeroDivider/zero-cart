# Deviations and open questions

Record every departure from the planning documents here, and every question that needed the owner. One row per item.

| Date | Task | Document and section | What differs | Reason | Decision (owner) |
|---|---|---|---|---|---|
| 2026-11-09 | APP-001 | `docs/implementation-plan.md` APP-001 | Bundle id is `com.zero.cart` instead of placeholder `com.example.zerocart`. | Owner chose the shipping reverse-DNS id now to avoid a pre-release rename. Plan text updated in the same task. | Approved: use `com.zero.cart`. |
| 2026-11-10 | APP-005 | `docs/testing-strategy.md` §5.6 | Hard-coded colour check stays a unit test under `flutter test`, not a separate shell grep in `tool/check.sh`. | APP-003 acceptance requires a failing test; APP-005 does not list a colour shell step. String hard-coding checks remain APP-024. | Pending owner. |
| 2026-11-10 | APP-005 | `docs/testing-strategy.md` §6 | CI job runs only `tool/check.sh`; no separate golden-test step yet. | Goldens do not exist until APP-026; APP-005 says the workflow runs the same script. | Pending owner. |
