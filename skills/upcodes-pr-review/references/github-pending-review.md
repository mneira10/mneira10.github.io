# Adding comments to the user's pending GitHub review

Only when the user explicitly asks. They edit and submit the review themselves, so never submit it, set an `event`, or post standalone comments.

## 1. Find the PR and the user's pending review

```shell
gh pr view --json number,url,headRefOid
gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviews(states:PENDING,first:5){nodes{id author{login} comments(first:100){totalCount nodes{path line body}}}}}}}' -f o=upcodes -f r=upcodes_web -F n=<number>
```

- If `headRefOid` doesn't match the HEAD you reviewed, check whether the extra commits touch the files you're commenting on. If they do, line numbers may have moved, so stop and tell the user before posting. If they don't, post anyway and mention the mismatch when you hand off.
- **The user has a pending review:** GitHub only returns pending reviews to their author, so any review this query returns is theirs. Add to it with the GraphQL mutation in step 4. GitHub allows one pending review per user, and the REST API can't add to it.
- **They have none:** create one with `POST /repos/upcodes/upcodes_web/pulls/<n>/reviews`, passing `commit_id` and a `comments` array. Leaving out `event` keeps it pending.

## 2. Check the user's draft

When the user asks you to post, post right away. Don't show drafts or ask for approval first: the comments land in the user's pending review, and they edit them before submitting. If they name specific comments, post only those; otherwise post all of the findings you reported.

- Skip findings the user already made, and tell them which ones you skipped.
- Point out duplicates in the user's draft, or their suggestions that conflict with other code.
- Write in your own voice. Don't imitate the user or write as if you were them.

## 3. Start each comment with the disclaimer

Every comment you add starts with this line, then a blank line, then the comment:

```
<sub>Comment added by <model name> and manually approved by <user's name>.</sub>
```

Replace `<model name>` with the model you're running as (e.g. `Claude Opus 5.5`) and `<user's name>` with the user's name from `git config user.name`. If that's empty, ask the user. Don't query GitHub for it. Don't reuse an old name. Add it only to your comments, not the user's.

## 4. Post the comments

- Take line numbers from the file at HEAD (`grep -n`), not from the diff output.
- Inline comments must sit on lines inside the diff. For renamed or moved files, only lines in diff hunks work (`git diff <base> HEAD -M -- <old> <new> | grep '^@@'`). Otherwise, anchor on a nearby changed line or use a file-level comment.

```graphql
mutation ($review: ID!, $path: String!, $line: Int!, $body: String!) {
  addPullRequestReviewThread(
    input: {
      pullRequestReviewId: $review
      path: $path
      line: $line
      side: RIGHT
      body: $body
    }
  ) {
    thread {
      id
    }
  }
}
# File-level: replace line/side with subjectType:FILE
```

For many comments, use a small Python script that loops over `(path, line or None, body)` and calls `gh api graphql`. Print OK or FAILED for each comment instead of stopping at the first error.

## 5. Verify and hand off

```shell
gh api graphql -f query='query{node(id:"<review id>"){... on PullRequestReview{state comments(first:100){totalCount}}}}'
```

Check that the state is still `PENDING` and the count equals the user's comments plus yours. Then tell them how many you added, which ones are file-level and why, and anything to fix in their own draft. They finish from "Files changed" → "Finish your review".
