# Check: styleguide

Check the diff against the repo's written rules. Read the current files in the checkout; they win over the summary in [../conventions.md](../conventions.md):

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
