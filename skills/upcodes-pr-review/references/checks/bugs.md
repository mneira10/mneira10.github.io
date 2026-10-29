# Check: bugs

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
- Auth and permissions on new endpoints; data from one org/user reachable by another.
- Frontend: stale closures, effects with missing or wrong deps, race conditions between requests, state not reset when props/route change, SSR vs browser-only code (`window`).
- Off-by-one, pagination, ordering assumptions, timezone handling.
- Error handling that swallows exceptions or reports success on failure.

Label findings `bug`. Not your job: style, naming, simplification.
