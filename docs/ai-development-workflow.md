# AI-assisted development workflow

ZeroCart is planned by the owner with Claude (chat) and implemented by Cursor Agent with Auto model selection. This document is the process; `AGENTS.md` is the short version the agent reads every time. Everything here is model-independent: the selected model may change between tasks.

## 1. Roles

- **Owner:** approves decisions, runs tasks one at a time, reviews at gates, merges to `main`, decides releases.
- **Cursor Agent (Auto):** implements one task per chat, tests, commits on a task branch, reports honestly.
- **Subagents** (`.cursor/agents/`): `spec-checker` (read-only, start of task), `verifier` (runs checks), `code-reviewer` (read-only, before reporting). They keep long output and review out of the main context. They use the parent's model (the default `inherit`); do not pin models.

## 2. Per-task procedure

Owner:
1. `git status` is clean, you are on `main`, and the previous task is merged.
2. Open a **new** Agent chat (Agent mode, model Auto). One task per chat.
3. Paste the start prompt (section 3).
4. Read the report. Run `tool/check.sh` yourself. Inspect `git log main..HEAD --oneline` and `git diff main...HEAD`.
5. Merge when satisfied: `git switch main && git merge --no-ff task/APP-0NN-slug`. Otherwise reply in the same chat with the changes you want.

Agent (Analyze, Plan, Implement, Verify, Document):
1. Create the branch `task/APP-0NN-short-slug` from `main`.
2. Run `spec-checker`; read the cited documents and existing code.
3. State the plan in at most 10 lines.
4. Implement in small steps, committing after each (Conventional Commit, task id, `Assisted-by` trailer).
5. Add or update tests with the code. Run the checks (`verifier`).
6. Run `code-reviewer`; fix blocking findings; commit.
7. Update only the listed docs; log deviations in `docs/deviations.md`; commit.
8. Report (section 6). Stop at review gates.

## 3. Prompts

**Start a task**
```
Implement task APP-0NN according to the approved product specification, architecture, ADRs, and acceptance criteria. Follow AGENTS.md and the project rules. Verify your work before proceeding. Work on branch task/APP-0NN-<slug>, commit after every step, do not push or merge.
```
**Continue after review comments**
```
Continue task APP-0NN on the current branch. Apply these changes: <list>. Keep committing per step, re-run checks, update the report.
```
**Review gate** (at APP-008, 014, 022, 027, after the agent reports)
```
Do not write code. Read the diff of branch task/APP-0NN-<slug> against main and list: deviations from the docs, risks, and anything you could not verify. Then propose, but do not apply, changes to the plan.
```
**Bug fix**
```
Fix this bug on a new branch fix/<slug>: <steps to reproduce, expected, actual>. First write a failing test, then the fix. Commit each step. Report as usual.
```

## 4. Auto model practices

- Auto may switch models between tasks and even between messages. Keep tasks small (the plan already does) and rely on repository documents, not chat history.
- Reference files explicitly (`@AGENTS.md`, `@docs/implementation-plan.md`) when a model seems to ignore the rules.
- Do not run several tasks in parallel with one agent. Subagents are for review and checks, not for parallel feature work, and they cost extra usage.
- Usage limits depend on your Cursor plan and change over time; check the dashboard. If you run out, wait or continue manually; the plan is stable between sessions because everything is in the repo.
- If an agent loops or degrades after 3 failed attempts, stop, `git status`, and either reset the task branch (`git switch main && git branch -D task/...`) or start a fresh chat with the same prompt.

## 5. Commits and branches

- Branch per task: `task/APP-0NN-short-slug`. Bug fixes: `fix/<slug>`. Docs-only: `docs/<slug>`.
- Conventional Commits, task id in the subject, `Assisted-by: Cursor Agent (Auto)` as the last line. Every commit passes format and analysis; the last commit of a task has all tests green.
- The agent never pushes, tags, amends, rebases or merges. You push and merge. Merge with `--no-ff` so each task stays visible in history.
- Generated files are never committed; Drift schema snapshots are.

## 6. Report template (the agent ends every task with this)

```
Task: APP-0NN <title>   Branch: <name>   Commits: <n>
Implemented: <bullets mapped to acceptance criteria>
Verified (commands run, results): <exact commands and outcome>
Not verified: <what could not be run and why>
Dependencies added: <package, version, page checked>
Deviations from the plan: <none | list, and the docs/deviations.md entry>
Questions for the owner: <none | list>
```
A report that lists no "Not verified" items on a task involving devices, platforms or CI should be treated with suspicion.

## 7. Failure handling

- Ambiguous rule, conflicting documents, unconfirmable API, out-of-scope need, security-sensitive change: stop and ask (AGENTS.md hard stops).
- A failing check the agent cannot fix after 3 genuine attempts: stop with the failure output and the attempts made. Do not weaken tests.
- A needed departure from the architecture is allowed only when logged in `docs/deviations.md` and approved by you; update the affected document in the same change after approval.

## 8. Owner review checklist

- Does the diff match the task and nothing else?
- Do tests cover business rules and failure paths, and do they fail without the code?
- Any logic in widgets, hard-coded tokens or strings, new dependencies, or generated files?
- Is the report honest (commands, not claims)?
- At gates: run the app on a device or simulator and walk the flows named in the task.

## 9. AI transparency

The repository states in the README that planning and implementation are AI-assisted, and commits carry the `Assisted-by` trailer. The owner reviews and is responsible for everything merged.
