# Review Pull Request

Inspect a pull request, classify every actionable review or CI finding, make
authorized in-scope fixes, and verify the exact resulting head.

## Usage

```text
/review-pr [PR_NUMBER_OR_URL]
```

When no PR is supplied, resolve the PR for the current branch. Read
`AGENTS.md`, `.codex/skills/nitro-sound-workflows/SKILL.md`, and the conventions
for every changed path before editing.

## 1. Resolve Exact State

```bash
git status --short --branch
gh pr view <PR> --repo hyochan/react-native-nitro-sound \
  --json number,title,state,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,mergeStateStatus,reviewDecision,statusCheckRollup,files,url
gh pr checks <PR> --repo hyochan/react-native-nitro-sound
```

Confirm that the local branch and head match the PR before changing code. Fetch
the base and head when needed; do not silently review a stale checkout.

## 2. Gather Feedback

Inspect all of these, not only the latest conversation comment:

- PR reviews and requested changes
- Inline review threads, including resolved state
- Top-level PR comments
- Failed or cancelled required checks and their job logs
- The full base-to-head diff and generated-file changes

Use the GitHub connector when available. Use `gh` for current-branch discovery,
Actions logs, or GraphQL thread data that the connector does not expose.

## 3. Classify Findings

For each thread or failure, choose one:

- **Valid and in scope**: fix it in the current batch.
- **Already fixed**: point to current code or a pushed commit.
- **Outdated**: verify that the referenced code no longer exists.
- **Incorrect**: explain with concrete repository or platform evidence.
- **Needs a product decision**: stop and request maintainer direction.

Do not dismiss correctness, data-safety, permission, lifecycle, or release
findings as follow-up work merely because they are inconvenient. Reject style
preferences and unrelated refactors.

## 4. Implement And Verify

Preserve existing user changes. Never hand-edit `nitrogen/generated/**`; update
the spec or source and regenerate with `yarn nitrogen` or `yarn prepare`.

Run the path matrix from `$nitro-sound-workflows`. At minimum:

```bash
yarn typecheck
yarn lint
yarn test
git diff --check
```

Add iOS, Android, Web, codegen, and device E2E checks required by the changed
surface. Do not call a runtime finding fixed from compilation alone.

If automated review skipped the current head, run one complete
`$review-self` round against the exact base and head. Do not recursively invoke
this command from that fallback.

## 5. Publish Only When Authorized

Commit and push only if the user authorized those actions. Stage only the files
owned by the fix batch. After the pushed head is verified:

- Reply to each fixed inline thread with the plain commit hash and a concise
  explanation.
- Resolve only fixed, disproved, or genuinely outdated threads.
- Leave decision-dependent threads unresolved.
- Re-read checks and reviews for the new head.

Do not request a reviewer or retrigger a bot on a no-op poll. If the user asks
to wait for async checks or feedback, poll through a real monitoring mechanism;
do not use a sleeping shell loop.

## Completion Gate

Report the PR URL and exact head, findings fixed or rejected, unresolved
threads, checks run, runtime rows tested, and any pending or blocked state. A PR
is clean only when required checks pass, no actionable feedback remains, and
the final diff has received a complete self-review.
