# Check: reuse and existing patterns

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
