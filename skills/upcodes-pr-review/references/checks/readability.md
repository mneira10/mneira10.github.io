# Check: readability

Can a reader follow the changed code without effort? Judge how it reads, not how many parts it has (the simplicity check covers that).

Look for:

- **Flow:** can you read the main path top to bottom? Early returns instead of deep nesting. Caller-before-helper ordering (per `docs/styleguide.md`).
- **Names:** do they say what the thing is or does? Is one concept named the same way throughout the feature? Code moved from a script often keeps its old names. Keep the accepted `pub`, `juris`, `occ`, `es` vocabulary.
- **Locality:** is related code kept together, or does the reader have to jump between files and distant functions to follow one behavior?
- **Tiny helpers** that hide trivial logic behind a name and make the reader jump to see a one-liner.
- **Comments:** missing where the *why* isn't obvious; stale or restating the code where they exist.
- **Magic values:** bare numbers or strings whose meaning isn't clear from context.

## Complexity needs a reason

If code is harder to read than an obvious alternative, there has to be a good reason, such as measured performance, a real constraint of a library or API, or a correctness edge case. Look for that reason in comments, the PR description, and the surrounding code. If you find it, don't flag the code; if the reason isn't written down, suggest a comment instead. If there's no reason, propose the readable version.

Not your job: whether the design has too many layers or too much state (simplicity), style-guide rules (styleguide), bugs.
