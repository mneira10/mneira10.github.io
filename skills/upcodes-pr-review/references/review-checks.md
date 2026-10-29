# Review checks

Each reviewer reads Shared rules and Calibration, then its assigned Check section.
For styleguide, also read UpCodes conventions; for AI features, read AI review
context. Stay within the assigned scope.

## Shared rules

You are one of several reviewers looking at the same PR. Each reviewer has one narrow focus. Stay inside yours: another agent covers the rest, so going outside your focus only creates duplicates.

- Review the checkout locally. It's read-only: don't edit files, stash, switch branches, fetch, run migrations, or write to GitHub.
- The orchestrator gives you the base, HEAD, diff command, PR description, and existing review comments. Security runs independently without previous findings or review comments; the orchestrator handles its duplicates afterwards. Other reviewers shouldn't repeat points already raised.
- Read the changed files in full plus the code around them, not just the diff hunks. If the worktree is dirty, read committed code with `git show HEAD:<path>`.
- Focus on problems this PR introduces, not pre-existing ones.
- Leave linting, type checks, formatting, and the test suite to CI. Only run a targeted test when it settles a specific question.
- Every suggestion needs a concrete alternative (a short sketch helps) and must keep the behavior callers rely on. "Simplify this" with no alternative isn't a finding.
- Read [Calibration](#calibration) for the bar and the "don't comment on" list.
- Zero findings is a valid result. Don't pad.

### Output

Return only a list of findings, most valuable first, each in this shape:

```
### <short title>
- check: <your check name>
- label: bug | improvement | convention   (add "optional" if it is)
- location: path:line   (line numbers from the file at HEAD, via grep -n, not from the diff)
- problem: <what's wrong, concretely>
- fix: <the proposed change, with a sketch if useful, and why it's better>
- confidence: high | medium | low
```

If you have nothing, return `No findings.` and one line on what you checked.

## Calibration

These examples are illustrative, not real comments from past reviews. Each one has a note on when not to use it.

**Simplification, even though the code works:**
"`selectedItems` is derived entirely from `items` and `selectedIds`, but this stores a second copy and uses effects to keep it in sync. Compute it from those inputs during render and drop the extra state and effects."
Skip it if the value isn't purely derived (e.g. it's an independent snapshot) or if there's a measured performance reason.

**Collapse unneeded layers:**
"This registry, factory, and adapter all serve one fixed implementation, and the caller only needs `parseReport`. Calling it directly removes three layers."
Skip it if there are other consumers or a real public extension point.

**Readability:**
"These flags encode mutually exclusive loading, ready, and failed states. A single `status` would make the branches explicit and remove the resets that keep the flags in sync."
Skip it if the flags are truly independent.

**Footgun (not a proven bug):**
"`saveResult` also consumes a credit, which is surprising for callers updating an existing result. Make that effect explicit in the name, or split it from saving."
Check the real callers first. Unless you can show a wrong charge, present it as a design issue, not a billing bug.

**Bug:**
"When the credit limit is `0`, this condition skips enforcement because zero is falsy. Check `is not None` so accounts with no credits left still hit the limit."
Skip it if zero means unlimited, the value is always positive, or a caller already handles zero.

**Existing pattern:**
"`formatJurisdictionName` reimplements what `getJurisDisplayName` in `src/utils/juris.ts` already does, including the edge case for county-level jurisdictions. Call the existing helper and delete this one."
Skip it if the existing code behaves differently in a way this caller needs. Then say why in the PR rather than leaving two near-duplicates unexplained.

**Convention:**
"This query should live in the existing `common/db` helper, per the style guide. The endpoint can call that helper directly."
Scripts are exempt, and commits can live in business logic.

**Missing regression test:**
"This test mocks the helper that has the bug, so it passes even with the original failure. Exercise the zero-limit case through the real helper."
Look at the existing tests before asking for a new one.

**Unproven quality claim:**
"The schema tests cover parsing, but they don't show the claimed recall improvement. A before/after comparison on representative sheets would, tracking false positives as well as missed findings."
Only when the PR claims an improvement or the risk is high. Don't demand a benchmark for every model config change.

### Don't comment on

- Performance worries without a real costly path.
- Adding an abstraction just to remove a few repeated lines.
- Problems a linter already reports.
- "Simplify this" with no concrete alternative.
- Removing safeguards or squeezing clear code into a one-liner.
- Pre-existing problems the PR doesn't touch.
- Anything already in Mauro's pending review.

Also, don't rank a big simplification below small nits just because it isn't a bug, and don't call a naming preference a serious bug.

## Check: readability

Can a reader follow the changed code without effort? Judge how it reads, not how many parts it has (the simplicity check covers that).

Look for:

- **Flow:** can you read the main path top to bottom? Early returns instead of deep nesting. Caller-before-helper ordering (per `docs/styleguide.md`).
- **Names:** do they say what the thing is or does? Is one concept named the same way throughout the feature? Code moved from a script often keeps its old names. Keep the accepted `pub`, `juris`, `occ`, `es` vocabulary.
- **Locality:** is related code kept together, or does the reader have to jump between files and distant functions to follow one behavior?
- **Tiny helpers** that hide trivial logic behind a name and make the reader jump to see a one-liner.
- **Comments:** missing where the *why* isn't obvious; stale or restating the code where they exist.
- **Magic values:** bare numbers or strings whose meaning isn't clear from context.

### Complexity needs a reason

If code is harder to read than an obvious alternative, there has to be a good reason, such as measured performance, a real constraint of a library or API, or a correctness edge case. Look for that reason in comments, the PR description, and the surrounding code. If you find it, don't flag the code; if the reason isn't written down, suggest a comment instead. If there's no reason, propose the readable version.

Not your job: whether the design has too many layers or too much state (simplicity), style-guide rules (styleguide), bugs.

## Check: simplicity and footguns

First understand what the change is meant to do. Then ask what the simplest version would look like. Don't assume the author's structure is the only option. Simpler means less to understand, not fewer lines.

### Fewer moving parts

- Derived values instead of stored-and-synced state. One source of truth.
- Calling an existing function directly instead of adding a wrapper, layer, registry, or adapter.
- **Unneeded generality:** code built for hypothetical future needs (options nobody passes, extension points with one implementation) that can be collapsed.
- **Simpler data:** several flags that really encode one state, needless conversions, shapes that allow invalid combinations.

### Footguns

Things that make the code easy to misuse, even if nothing is broken today:

- hidden side effects (a "save" that also charges a credit);
- required call order;
- surprising defaults;
- shared mutable state;
- ambiguous booleans in signatures.

Check the real callers first. Report these as design risks (`improvement`), not bugs. If you can show a concrete wrong result, say so and the orchestrator will pass it to the bugs reviewer.

### Complexity needs a reason

Accept extra complexity only with a real reason: measured performance, an external constraint, a correctness edge case. Look for it in comments, the PR description, and the surrounding code before flagging.

Not your job: names and flow (readability), whether something already exists elsewhere in the codebase (reuse), style-guide rules (styleguide).

## Check: reuse and existing patterns

Your job is to search outward across the codebase, not to read the diff closely.

1. List every new thing the PR adds: helper functions, components, hooks, queries / `common/db` helpers, constants, types, utilities, endpoints, and structural patterns (how it fetches data, handles errors, structures a worker, wires a form, and so on).
2. For each one, search the **whole repository**, not just nearby files, for:
   - code that already does the same job, possibly under a different name (search by behavior and key calls, not just by name);
   - the established way of doing the same kind of thing elsewhere.
3. Flag:
   - **reimplementations:** point to the existing code (`path:line`) and say whether it handles the same edge cases;
   - **new patterns** that depart from the established one, unless the PR explains why. The style guide says new patterns merit team discussion, and minor departures should be explained.

Before flagging, check that the existing code really fits this caller. If it behaves differently in a way the caller needs, say so, and suggest the PR explain the difference rather than leaving two near-duplicates unexplained.

Don't suggest adding a new shared abstraction just to remove a few repeated lines.

Not your job: whether the new code itself is simple or readable, bugs.

## Check: styleguide

Check the diff against the repo's written rules. Read the current files in the checkout; they win over the summary in [UpCodes conventions](#upcodes-conventions):

- `docs/styleguide.md`
- `.github/copilot-instructions.md`
- `backend/.cursor/BUGBOT.md` and/or `frontend/.cursor/BUGBOT.md`, whichever the diff touches
- any other style docs these link to that are relevant to the changed code

Rules:

- Every finding cites the rule and the file it comes from (e.g. "per `backend/.cursor/BUGBOT.md`: prefer custom exceptions with useful messages").
- Only flag rules that are actually written down. Personal taste isn't a convention.
- Leave anything a linter or type checker enforces to CI.
- Respect the documented exceptions (e.g. scripts can do ORM work outside `common/db`; commits can live in business logic; documented context use cases are allowed).
- Unrelated fixes bundled into the PR count: the style guide says to keep them out.
- Disabled lint/type checks need a real reason or an explanation.

Label findings `convention`. Not your job: bugs, design simplicity, reuse.

## Check: bugs

Find behavior that is wrong, not code that could be nicer.

For every bug, show:

1. the input or state that triggers it;
2. the path it takes through the code (`path:line` steps);
3. the wrong result (wrong value, crash, data loss, double charge, leaked data, etc.).

Then look for guards, validation, or callers that already prevent it. If one does, drop the finding. If you can't show all three steps, it isn't a bug: either drop it or report it as an `improvement` with `confidence: low` and call it a design risk.

Common places to look in this codebase:

- `None` vs zero / empty string / empty list (falsy checks that skip a legitimate `0`).
- Soft-deleted rows: `get_` helpers that include or exclude `deleted_at` rows unexpectedly; `update_` helpers touching `deleted_at`. `UNSPECIFIED` vs `None` for optional ORM params.
- Transactions and commits: partial writes on error, missing commit/rollback, work outside the session.
- Retries and workers: does a retry or partial failure duplicate rows, credit consumption, or external calls?
- Frontend: stale closures, effects with missing or wrong deps, race conditions between requests, state not reset when props/route change, SSR vs browser-only code (`window`).
- Off-by-one, pagination, ordering assumptions, timezone handling.
- Error handling that swallows exceptions or reports success on failure.

Label findings `bug`. Not your job: style, naming, simplification.

## Check: security

Run independently in a fresh subagent context, without reading other reviewers' findings or previous PR reviews. Review the changed code and the callers, guards, and configuration that determine its security. Stay within this PR's changes; skip clearly inapplicable areas rather than inventing concerns.

Trace attacker-controlled inputs across trust boundaries to sensitive operations or data. Focus on the areas the diff touches:

- Authentication and authorization: missing or bypassed permissions, cross-account or cross-organization reads and writes, privilege escalation, and changed session or token handling.
- Injection and unsafe execution: SQL, shell, template, and browser injection; unsafe deserialization; untrusted input reaching executable code.
- Network and file access: server-side requests to attacker-chosen destinations, unsafe redirects, path traversal, and uploaded files reaching unintended locations or execution paths.
- Sensitive information: secrets or private data exposed through responses, logs, errors, client bundles, or external services.
- Security controls in changed configuration, dependencies, and scripts. For AI features, trace whether untrusted retrieved content or model output can bypass tool authorization or expose protected data.

For each finding, identify the attacker's required access, the input or action they control, the reachable `path:line` sequence, the missing or ineffective protection, and the concrete impact. Read existing authorization checks, validators, escaping, and framework protections to try to rule it out. A dangerous-looking API alone isn't evidence of a vulnerability.

Use the shared finding format with `check: security`. Include the attack scenario and evidence in `problem`. Label a confirmed vulnerability `bug`; clearly distinguish an unverified design risk from an exploit that the code allows, and state what evidence is missing.

Keep analysis local and read-only. Don't probe deployed services, use real credentials, install scanners, or run exploit payloads against shared systems. If a safe local check is needed to settle a claim, describe it for the orchestrator to assess.

## Check: tests

Spawned when the PR fixes a bug, or adds or changes tests. Read `docs/testing.md` first.

1. **Regression test for backend fixes.** A backend bug fix needs a test that fails before the fix and passes after. Work out what the original failure was (from the PR description and the diff), then check whether the new test would actually have failed on the old code. Reason it through by reading the base version (`git show <base>:<path>`). Don't swap files in the worktree to try it: other reviewers are reading it at the same time. If only a run would settle it, say so in the finding and the orchestrator can decide.
2. **Mocks that hide the bug.** A test that mocks out the faulty code doesn't count. Flag tests whose mocks replace the very function or query being fixed or tested.
3. **Assertions.** Do the tests assert on the behavior that matters, or only that something ran (e.g. "no exception", "called once")?
4. **Existing tests.** Look at what's already covered before asking for a new test. Point to the existing test file where the new case belongs, and to existing fixtures or factories to reuse.

Don't demand tests for trivial changes, and don't ask for coverage just for its own sake. Not your job: bugs in the production code itself.

## Check: migrations

Spawned when the PR adds or changes database migrations or models. Read `docs/database/database_migrations.md` first.

- Read the generated operations, not just the model change. Autogenerated renames often come out as drop + add, which loses data.
- **Deploy order:** the migration runs before or alongside new code while old code is still serving. Can old code still work against the new schema (dropped/renamed columns, new NOT NULL columns without a server default)?
- Data migrations: are they idempotent, and do they finish in reasonable time on production-sized tables? Do they lock large tables?
- Indexes and constraints: do they match how the new code queries? Is a new unique constraint safe for existing data?
- Does the downgrade work, or is it reasonably documented as one-way?
- Does the SQLAlchemy typing match the existing patterns for equivalent column types?

Never apply, run, or generate a migration.

## Check: AI features

Spawned when the PR changes AI, prompt, retrieval, agent, or model code (plan review, specs code review, copilot).

Follow [AI review context](#ai-review-context). Use only the rows that match the change, and don't turn every AI PR into an architecture audit.

Tie each finding to user impact: missed violations, unsupported findings, wrong references, confusing states, double billing, or slow responses. Separate real bugs (show the trigger and path, as for any bug) from untested quality claims (an evaluation gap, not proof of a regression). Don't run paid evaluations or production jobs.

## UpCodes conventions

A summary of the repo's documented rules, taken on 2026-09-07. The current files in the checkout win if they differ.

### General: docs/styleguide.md and .github/copilot-instructions.md

Keep it simple and follow existing patterns. New patterns merit team discussion; minor departures should be explained. Prefer caller-before-helper ordering. Do not disable lint/type checks casually; seek a real fix and explain necessary suppressions unless obvious. Keep unrelated fixes out of the PR.

### Backend: backend/.cursor/BUGBOT.md

- Distinguish `None` from zero and other falsy values. Do not mechanically replace legitimate boolean conditions.
- Keep production ORM logic in `common/db`; scripts are exempt, and commits may live in business logic.
- Utility files should not import the server-instantiating `app.py`.
- Prefer custom exceptions with useful diagnostic messages.
- Prefer explicit methods over properties; documented shims and very frequent uses are exceptions.
- Prefer descriptive names, retaining the accepted `pub`, `juris`, `occ`, and `es` vocabulary.
- Match existing SQLAlchemy typing patterns for equivalent column types.
- ORM helpers (`docs/styleguide.md`): use the `UNSPECIFIED` sentinel rather than `None` for optional params unless `None` is a real value, and compare with `is`. `get_` functions must make filtering visible in the signature (e.g. `include_deleted: bool = False`) rather than silently excluding soft-deleted rows. `update_` must not set `deleted_at`.
- Keep naming consistent for one concept across a feature. Code moved from a script often keeps its old names (e.g. "specs code compliance" vs "spec code review").
- Name agent/tool limits as module constants alongside their siblings rather than leaving bare numbers.
- Backend bug fixes require a test failing before and passing after the fix. A test mocking away the faulty behavior does not satisfy this requirement.

### Frontend: frontend/.cursor/BUGBOT.md and style guide

- Prefer explicit behavior and avoid unnecessary React context; the documented context guidance allows similar official use cases and deep prop drilling.
- Underscored components under `src/components` stay within their top-level component directory.
- Components leave layout concerns such as margins to their callers. Prefer granular skeletons sharing code with the actual component.
- Prefer explicit function signatures, avoid unjustified `any`, and keep component interfaces near their component.
- Use `useImmutableSWR` for data not requiring frequent revalidation. Avoid subscribing via `useRouter` solely to read URL information in callbacks/effects; keep any `window.location` use in browser execution paths.
- URL query parameters use snake case. `is`/`has` names describe boolean-like values, including the documented state/ref cases. Spell the editor framework `Tiptap`.
- Prefer Tailwind and rem units. Avoid on-load transitions of non-composited properties because of layout shifts.

### Migrations

Read `docs/database/database_migrations.md`. Check the generated operations (especially renames) and whether they're safe for the deploy order. Never apply a migration during a review.

## AI review context

Questions to ask when a PR changes AI features (plan review, specs code review, copilot). Use only the rows that match the change, and don't turn every AI PR into an architecture audit.

| Changed area | Investigate |
| --- | --- |
| Page classification, selection, context limits | Can an early classification or truncation silently exclude relevant sheets, references, or requirements? Is the behavior intentional and measured? |
| Findings, evidence, citations | Does evidence substantiate the claim, beyond satisfying a schema? Do IDs survive conversion/persistence? Is the code reference associated with the intended jurisdiction and edition? |
| Requirement tracking and grouping | Can a noncompliant requirement be lost, an issue duplicated, or distinct issues merged? Does the changed state transition preserve intended coverage? |
| Worker lifecycle and reruns | Can partial failures or retries duplicate persisted findings, credit consumption, or external work? Is the actual retry path protected? |
| Retrieval and context packing | Can filters, ordering, caps, or oversized entries drop evidence that downstream behavior relies on? Trace real inputs rather than asserting all truncation is a bug. |
| Prompts, schemas, model configuration | Are model identifiers, provider routing, tool/media support, output contracts, token limits, and usage accounting consistent with the call path? Verify current external capabilities only when needed. |
| Project context sent to the model | Which project facts reach the prompt? Code-review findings depend on occupancy classification and construction type (fire resistance, allowable area, egress). `Project` has `building_type` (a coarse market category), `commercial_building_subtype`, `building_size`, `scope_of_work`, `juris_key` and `code_year`, but no occupancy or construction type. Check whether fields shown to users in the UI are left out of the prompt, and whether the agent is told to flag missing facts (e.g. `MISSING_INFORMATION`) instead of assuming. |
| Agent tool scoping | Do search, read and citation/validation tools cover the same scope? For example, a book-wide grep paired with a division-only read means the agent can find text it cannot open. Check that tests actually exercise the cross-scope path. |
| Parallel agent fan-out | If one agent fails, do its siblings keep spending on LLM calls before the whole job is retried? Is LLM output that the model must produce and that gets validated (code citations, evidence) actually persisted or shown to users, or is it thrown away? |
| Result display and polling | Do counts add up issues across historical runs, or include resolved/not-applicable items, when neighbouring counts exclude them? Does a frequently polled endpoint load heavy columns (e.g. full spec `xml_doc`) just to compute a flag? |
| Claimed quality improvements | What comparable evaluation supports precision, recall, citation accuracy, latency, and cost effects? Treat missing evidence as an evaluation gap, not proof of a regression. |

Useful starting points in the repository (discover current names if moved):
- `backend/api/projects/plan_checker/`
- `backend/api/projects/__tests__/test_plan_checker/`
- `backend/scripts/workers/plan_check_worker.py`
- `backend/api/copilot/`
- `backend/common/db/plan_check_user_file_agent_run.py`
- `backend/api/specs/spec_code_review_utils.py` and `backend/scripts/workers/spec_code_review_worker.py` (specs code review)

Tie findings to user impact: missed violations, unsupported findings, wrong references, confusing states, double billing, or slow responses. Schema tests and quality evaluations answer different questions, so for model changes separate a real bug from an untested quality guess. Don't run paid evaluations.
