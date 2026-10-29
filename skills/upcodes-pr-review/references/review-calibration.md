# Example comments

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

## Don't comment on

- Performance worries without a real costly path.
- Adding an abstraction just to remove a few repeated lines.
- Problems a linter already reports.
- "Simplify this" with no concrete alternative.
- Removing safeguards or squeezing clear code into a one-liner.
- Pre-existing problems the PR doesn't touch.
- Anything already in Mauro's pending review.

Also, don't rank a big simplification below small nits just because it isn't a bug, and don't call a naming preference a serious bug.
