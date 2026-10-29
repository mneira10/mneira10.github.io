# Check: tests

Spawned when the PR fixes a bug, or adds or changes tests. Read `docs/testing.md` first.

1. **Regression test for backend fixes.** A backend bug fix needs a test that fails before the fix and passes after. Work out what the original failure was (from the PR description and the diff), then check whether the new test would actually have failed on the old code. Reason it through by reading the base version (`git show <base>:<path>`). Don't swap files in the worktree to try it: other reviewers are reading it at the same time. If only a run would settle it, say so in the finding and the orchestrator can decide.
2. **Mocks that hide the bug.** A test that mocks out the faulty code doesn't count. Flag tests whose mocks replace the very function or query being fixed or tested.
3. **Assertions.** Do the tests assert on the behavior that matters, or only that something ran (e.g. "no exception", "called once")?
4. **Existing tests.** Look at what's already covered before asking for a new test. Point to the existing test file where the new case belongs, and to existing fixtures or factories to reuse.

Don't demand tests for trivial changes, and don't ask for coverage just for its own sake. Not your job: bugs in the production code itself.
