# AI and plan-review checks

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
