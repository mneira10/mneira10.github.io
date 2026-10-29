# Check: simplicity and footguns

First understand what the change is meant to do. Then ask what the simplest version would look like. Don't assume the author's structure is the only option. Simpler means less to understand, not fewer lines.

## Fewer moving parts

- Derived values instead of stored-and-synced state. One source of truth.
- Calling an existing function directly instead of adding a wrapper, layer, registry, or adapter.
- **Unneeded generality:** code built for hypothetical future needs (options nobody passes, extension points with one implementation) that can be collapsed.
- **Simpler data:** several flags that really encode one state, needless conversions, shapes that allow invalid combinations.

## Footguns

Things that make the code easy to misuse, even if nothing is broken today:

- hidden side effects (a "save" that also charges a credit);
- required call order;
- surprising defaults;
- shared mutable state;
- ambiguous booleans in signatures.

Check the real callers first. Report these as design risks (`improvement`), not bugs. If you can show a concrete wrong result, say so and the orchestrator will pass it to the bugs reviewer.

## Complexity needs a reason

Accept extra complexity only with a real reason: measured performance, an external constraint, a correctness edge case. Look for it in comments, the PR description, and the surrounding code before flagging.

Not your job: names and flow (readability), whether something already exists elsewhere in the codebase (reuse), style-guide rules (styleguide).
