# UpCodes conventions

A summary of the repo's documented rules, taken on 2026-09-07. The current files in the checkout win if they differ.

## General: docs/styleguide.md and .github/copilot-instructions.md

Keep it simple and follow existing patterns. New patterns merit team discussion; minor departures should be explained. Prefer caller-before-helper ordering. Do not disable lint/type checks casually; seek a real fix and explain necessary suppressions unless obvious. Keep unrelated fixes out of the PR.

## Backend: backend/.cursor/BUGBOT.md

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

## Frontend: frontend/.cursor/BUGBOT.md and style guide

- Prefer explicit behavior and avoid unnecessary React context; the documented context guidance allows similar official use cases and deep prop drilling.
- Underscored components under `src/components` stay within their top-level component directory.
- Components leave layout concerns such as margins to their callers. Prefer granular skeletons sharing code with the actual component.
- Prefer explicit function signatures, avoid unjustified `any`, and keep component interfaces near their component.
- Use `useImmutableSWR` for data not requiring frequent revalidation. Avoid subscribing via `useRouter` solely to read URL information in callbacks/effects; keep any `window.location` use in browser execution paths.
- URL query parameters use snake case. `is`/`has` names describe boolean-like values, including the documented state/ref cases. Spell the editor framework `Tiptap`.
- Prefer Tailwind and rem units. Avoid on-load transitions of non-composited properties because of layout shifts.

## Migrations

Read `docs/database/database_migrations.md`. Check the generated operations (especially renames) and whether they're safe for the deploy order. Never apply a migration during a review.
