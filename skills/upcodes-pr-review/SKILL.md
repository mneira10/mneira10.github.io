---
name: upcodes-pr-review
description: Review the currently checked-out UpCodes PR branch by fanning out narrow-scope subagents (readability, simplicity and footguns, reuse of existing patterns, style guide, bugs, and an independent security analysis, plus tests, migrations, and AI checks when relevant), then merge their findings into actionable local comments. Invoke after switching branches; does not fetch or switch branches. On explicit request, adds the comments to Mauro's pending (unsubmitted) GitHub review for him to edit and submit.
disable-model-invocation: true
---

# UpCodes PR review

The goal is to help the author make the change simpler, easier to read, and harder to misuse, without changing what it does. Look for better implementations even when the code works and CI passes. Zero comments is a valid result.

Gather the context once, give each subagent one narrow check, then merge their findings. All check briefs, calibration examples, conventions, and AI guidance are in [references/review-checks.md](references/review-checks.md). Resolve that path relative to this skill's directory.

## 1. Set up

Mauro checks out the branch before invoking this skill. Review that checkout locally. Don't fetch, switch branches, or write to GitHub unless he asks you to post comments (see step 5). Read-only `gh` calls to get PR context are fine.

- Find the base: use the ref he gives, otherwise the local default (`origin/HEAD`). Don't assume `main` or `master`. If the branch looks stacked or the base is unclear, ask.
- Review `git diff <merge-base> HEAD`. Say which branch, base, and HEAD you reviewed, and that local refs may be stale.
- If the worktree is dirty, review the committed code only (`git show HEAD:<path>`) and say so. Never stash or overwrite his changes.
- Read the PR description and existing comments (`gh pr view --comments`, plus inline review comments via `gh api repos/{owner}/{repo}/pulls/<n>/comments`), including anything in his pending review. If there's no PR yet, say so and continue.
- Skim the diff yourself so you know what the change is meant to do and which areas it touches.

## 2. Fan out the checks

Use the available subagent tool to run independent checks in parallel, respecting the session’s concurrency limit; run remaining checks in batches as slots become available. Each reviewer needs file reads and read-only shell commands.

| Check section | Run when |
| --- | --- |
| readability | always |
| simplicity and footguns | always |
| reuse and existing patterns | always |
| styleguide | always |
| bugs | always |
| security | always; a separate subagent with fresh context |
| tests | the PR fixes a bug, or adds or changes tests |
| migrations | migrations or DB models change |
| AI features | AI, prompt, retrieval, agent, or model code changes |

Skip a check when it clearly can't apply (e.g. reuse on a PR that only deletes code, styleguide on a one-line config bump), and say which ones you skipped.

Each subagent prompt contains:

1. The absolute path to `references/review-checks.md`, with instructions to read Shared rules, Calibration, and its assigned Check section. Include UpCodes conventions for styleguide and AI review context for AI features.
2. The repo path, branch, base ref, merge-base, HEAD, and the diff command. Say whether the worktree is dirty.
3. A short summary of what the PR is meant to do (from the description and your skim) and the list of changed files.
4. Points already raised by other reviewers or in Mauro's pending review, so they aren't repeated. For security, withhold previous findings and review comments until its independent run finishes; deduplicate afterwards.

Run security as its own analysis, separate from bugs and AI features. Start it without inherited review conversation, supplying its brief, checkout, diff, PR intent, and source context explicitly. It reports its findings before you merge or filter them.

Don't paste the full diff or file contents into the prompts; the subagents read them themselves.

If subagents aren't available, run security first as a separate pass, then the other checks one after another. Say that it could not run in an independent subagent.

## 3. Merge and verify

- **Deduplicate.** Different checks will flag the same lines. Merge them into one comment, keeping the strongest framing and the best fix.
- **Resolve conflicts.** If two checks propose incompatible fixes (e.g. readability wants a helper inlined, reuse wants it replaced with an existing one), pick one or present the trade-off in a single comment.
- **Verify bugs and security findings.** Read each cited path yourself and try to disprove the claim: look for guards, validation, framework protections, or callers that prevent it. For security, verify the attacker's access, reachable path, and impact. If it doesn't hold up, drop it or downgrade it to a design risk. Do the same for any finding with `confidence: low` that you're thinking of keeping.
- **Filter.** Drop findings that match the [don't comment on list](references/review-checks.md#dont-comment-on), anything already raised by other reviewers or in Mauro's pending review, and anything outside this PR's changes.
- **Check line numbers.** Make sure each `path:line` points at the right line in the file at HEAD.

## 4. Report

Order comments by value: serious bugs first, then substantial simplifications, then small issues and style nits. Don't rank a big simplification below small nits just because it isn't a bug. For each one, give:

- a short title and exact `path:line`;
- the problem;
- the proposed fix and why it's better.

Label each comment as a bug, an improvement, or a convention, and mark optional ones. Be direct and skip praise filler. Only ask a question when you actually need the answer.

End with one or two lines of scope and limitations: which checks ran, which were skipped and why, e.g. "Review only; checks left to CI."

## 5. Post to GitHub (only when asked)

Only when Mauro explicitly asks (e.g. "add these to the PR"). Follow [references/github-pending-review.md](references/github-pending-review.md). In short:

- Add comments to his **pending** review and never submit it.
- Skip anything he has already said in his draft.
- Post right away, without showing drafts or asking for approval. If he names specific comments, post only those.
- Write in your own voice. Don't imitate Mauro or write as if you were him.
- Start every comment with the disclaimer line described in that reference.
