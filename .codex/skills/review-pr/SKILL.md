---
name: review-pr
description: Inspect and finish react-native-nitro-sound pull requests by classifying review threads and CI failures, fixing valid findings, replying and resolving threads, using review-self when automated review is unavailable, and polling at five-minute intervals until the exact head is clean. Use for PR review, review feedback, CI failures, reviewer monitoring, or requests to keep reviewing until no actionable feedback remains.
---

# Review Pull Request

Own one PR review loop from exact-state discovery through a clean completion
gate. Keep this skill as the sole polling owner; invoke `$review-self` only for a
single fallback round.

## Preserve Authority And Scope

- Inherit commit, push, PR-comment, merge, and release authority from the user's
  original request. Do not expand it implicitly.
- Read `AGENTS.md`, `$nitro-sound-workflows`, and conventions for every changed
  path before editing.
- Preserve pre-existing local work. Never sweep-stage or discard unrelated,
  ignored, untracked, or generated files.
- Keep public GitHub messages in clear English unless explicitly requested
  otherwise.

## Resolve The Exact PR State

1. Resolve the requested PR, or the current branch's PR when omitted.
2. Fetch its actual base and head. Confirm the local branch matches the remote
   head before editing.
3. Record the PR number and URL, base/head names and SHAs, tree fingerprint,
   merge state, labels, review decision, check IDs, and working-tree state.
4. Gather all evidence:
   - reviews and requested changes;
   - unresolved and outdated inline review threads via GraphQL;
   - top-level PR comments and automated-review status;
   - failed, cancelled, queued, or successful Actions checks and logs;
   - the complete base-to-head diff, including generated changes.

Do not treat a stale local checkout, a pending reviewer, or a missing check as a
clean result.

## Classify And Address Every Finding

Classify each finding as one of:

- **Valid and in scope:** fix it in the current batch.
- **Already fixed:** cite current code or the pushed commit.
- **Outdated:** verify the referenced code no longer applies.
- **Incorrect:** reject it with concrete repository or platform evidence.
- **Decision required:** stop and request maintainer direction.

Do not defer a valid correctness, lifecycle, permission, data-safety, release,
or operational issue as future work. Reject pure style preferences, duplicate
findings, and unrelated refactors.

For fixes:

1. Change the source of truth; never hand-edit `nitrogen/generated/**`.
2. Regenerate through `yarn nitrogen` or `yarn prepare` when required.
3. Run `git diff --check` and the path matrix from `$nitro-sound-workflows`.
4. For audio runtime changes, obtain the required microphone approval and use
   the appropriate iOS, Android, or simulator audio E2E skill.
5. Commit and push one coherent verified batch when authorized.

## Reply And Resolve Threads

- Reply to an inline comment through its comment-specific reply endpoint, not a
  general PR comment.
- Put the plain commit hash in the reply so GitHub auto-links it; do not wrap the
  hash in backticks.
- Resolve only threads that are fixed, disproved, or genuinely outdated.
- Leave decision-dependent or still-valid threads open.
- After a head change, re-read all feedback and checks for the new SHA. Request
  another automated review only when the repository already uses that reviewer;
  never create trigger noise on a no-op poll.

## Use Review-Self As The Fallback

External review is useful evidence, not a permanent completion dependency. Mark
a reviewer unavailable for the current head when either condition holds:

- a terminal result explicitly says it skipped or failed due to quota, billing,
  rate limits, permissions, service availability, or diff limits; or
- two consecutive five-minute polls show neither actionable output nor an
  in-progress/requested state.

When unavailable, invoke `$review-self` for exactly one complete round against
the actual base and current head. Pass the request, acceptance criteria, changed
paths, existing feedback, and write authority. The fallback must not re-enter
this skill, request reviewers, or schedule another loop.

Cache fallback coverage by reviewer-failure set and head SHA. Invalidate it on
any head change. One clean fallback round may cover multiple unavailable
reviewers for that exact head.

## Poll Every Five Minutes

Run the first review round immediately. If asynchronous checks or reviewers
remain, use the product's recurring heartbeat or wake-up mechanism to re-enter
`$review-pr` after 300 seconds. Never emulate monitoring with `sleep`, a shell
loop, `nohup`, or an abandoned process.

Keep at most one active monitor for the target. Carry this compact state capsule:

- original goal and acceptance criteria;
- repo, PR, base, head SHA, and tree/working-tree fingerprints;
- seen check, review, comment, and thread IDs;
- reviewer availability and fallback coverage for the current head;
- poll count, consecutive clean count, start time, and finding/fix attempts;
- inherited commit, push, comment, merge, and release authority.

On each wake-up:

1. Re-resolve the PR and invalidate cached state if the head changed.
2. Fetch checks, reviews, comments, and unresolved threads.
3. Fix and verify new valid findings, then publish the batch when authorized.
4. Run or reuse head-specific fallback coverage for unavailable reviewers.
5. Avoid repeating expensive local checks when the code fingerprint is
   unchanged and only external state is pending.
6. Increment the clean count only after the full completion gate passes; reset
   it on any material change.

## Completion And Stop Gates

Declare the PR stable after two complete clean snapshots separated by five
minutes. A clean snapshot requires all of:

- required checks are terminal and successful, or their absence is explicitly
  supported by repository evidence;
- no actionable unresolved review thread or top-level finding remains;
- every unavailable automated reviewer has clean `$review-self` fallback
  coverage for the current head;
- the final diff was reread and required verification passed;
- the worktree and remote head match the recorded state.

Stop without claiming clean when a product decision is required, the same
finding survives two fix attempts, the same environment failure blocks three
rounds, the PR closes or changes incompatibly, or only unchanged pending state
remains after 12 polls (about one hour).

Finish with the PR URL and exact head, labels, findings and dispositions,
threads resolved or left open, checks and runtime rows, fallback coverage, two
clean-snapshot evidence, and any remaining blocker.
