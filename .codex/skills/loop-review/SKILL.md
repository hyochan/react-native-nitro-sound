---
name: loop-review
description: 'Run the react-native-nitro-sound change-to-main loop from the latest origin/main: implement and verify with the docs in the PR, stabilize with review-self, open or reuse a PR and review it until its exact head is clean, gate audio regression before merging, merge, and return to an exact clean main. Releases run only when the user also asks for one.'
---

# Loop Review

Own one react-native-nitro-sound change from a fresh `main` baseline through a
verified merge. Use the repository workflows as the source of truth instead of
duplicating their detailed commands.

Use `$loop-review-self` instead for a change whose every path is in its
qualifying scope; that lane needs no PR.

## Load The Workflows

Read these before acting:

- `AGENTS.md`
- `.codex/skills/nitro-sound-workflows/SKILL.md`
- `.codex/skills/review-self/SKILL.md`
- `.codex/skills/review-pr/SKILL.md`
- `.codex/skills/generate-doc/SKILL.md`
- `.claude/commands/commit.md`
- `.claude/commands/e2e-tests.md`
- `.claude/commands/release.md`, only when a release is requested

Check what the change touches before reading any of them from the branch:

```bash
git diff --name-only "$(git merge-base origin/main HEAD)"..HEAD
```

When the change edits `AGENTS.md`, `.codex/`, or `.claude/`, read every file
above from the recorded merge base for the whole run, as `$review-pr` requires
for PR-controlled instructions. A branch never rewrites the rules that judge
it.

An explicit `$loop-review` invocation, or an explicit natural-language request
for this complete loop, authorizes the in-scope commit, push, PR, review
replies, thread resolution, and merge. It does not authorize an npm release,
a prerelease, a manual deployment, unrelated cleanup, destructive recovery, or
product-code commits directly to `main`. Run the release phase only when the
same request also asks for a release.

Reuse the relevant open PR, including a contributor PR the maintainer can push
to. This loop authorizes one PR, not follow-up PRs.

## 1. Start From Current Main

Before editing task files:

1. Snapshot `git status --short --branch`. Preserve every existing change.
2. For a new task, require a clean worktree, then run `git fetch origin`, switch
   to `main`, and run `git pull --ff-only --no-tags origin main`.
3. Verify local `main` equals `origin/main`, then create a branch named
   according to `.claude/commands/commit.md`.
4. Record the starting main SHA. The implementation diff must descend from that
   SHA.

Never start new implementation on a stale local `main`. If invoked for work
already in progress, including an existing PR, do not manually switch branches,
stash, reset, or discard it. Treat that as a resumed loop, verify its merge-base
baseline, and use `$rebase-main` when an update from `origin/main` is needed.
Leave branches and worktrees owned by other automation, such as OpenMainty runs
under `~/.openmainty/runs/`, untouched. Stop for direction if an update would
overwrite unrelated user work.

## 2. Implement And Verify

Implement the requested scope and run the path matrix from
`$nitro-sound-workflows` for every touched path. Change `src/specs/*.nitro.ts`
first when the HybridObject surface changes, and regenerate with
`yarn nitrogen` or `yarn prepare`; never hand-edit `nitrogen/generated/**`.
Keep TypeScript, Web, Swift, Kotlin, and C++ behavior aligned, or document the
platform limitation.

A change to public API, platform behavior, or compatibility updates the docs it
affects in the same PR with `$generate-doc`: `README.md`, `docs/`, and the
`example/` app when behavior changes. Leave `CHANGELOG.md` to the release
workflow. Do not proceed while the working diff has a known failing required
check.

Once it works, reread the diff and remove dead code, debugging output, and
churn the task does not need, then rerun the affected checks.

## 3. Stabilize With Review Self

Run `$review-self` immediately against the complete base-to-working-tree diff.
Fix every validated in-scope finding and rerun affected verification. Continue
with five-minute recurring wake-ups until two consecutive complete snapshots are
clean, as defined by the review-self skill.

Do not emulate recurring review with a shell sleep loop. Keep the loop state out
of tracked files. Any material diff change resets the consecutive-clean count.

## 4. Commit And Open The PR

Follow `.claude/commands/commit.md` with `--all --pr`:

- Stage only files owned by the task, in its commit order.
- Write English conventional commit messages that pass commitlint.
- Push the branch and open an English PR against `main` that links the issue
  (`Closes #N`) and states platform impact and what was and was not verified.
- Add the labels from its label guide.

For an existing contributor PR, push to its head branch when
`maintainerCanModify` is true, and add a maintainer section to the PR body
instead of opening a new PR.

Record the PR number and exact head SHA. A push invalidates all prior clean
review coverage.

## 5. Review The PR Until The Exact Head Is Clean

Run `$review-pr` immediately, then re-enter it every five minutes through the
product's recurring wake-up mechanism. It owns thread classification, inline
replies, thread resolution, reviewer availability, the `$review-self`
fallback, and polling.

After a head change, CodeRabbit reviews the new head automatically. Request a
Gitdog review with an `@gitdogai review` PR comment only when Gitdog has already
reviewed this PR; never post trigger noise on a no-op poll. A cancelled job
with no failed step, such as a runner timeout, is infrastructure: rerun it or
show that the same build passed in its sibling workflow, and say which.

Clean means all of the following hold for the same head SHA, judged by the
rules on the merge base when the branch edits them:

- zero unresolved actionable review threads or top-level findings;
- CodeRabbit is clean, or its unavailable result has clean `$review-self`
  fallback coverage for this head;
- every required check (`lint`, `test`, `build-library`, `build-web`,
  `build-ios`, `build-android`, and the `ci-*` workflows) is terminal and
  successful;
- the PR is mergeable and the branch contains every required update from main;
- the worktree is clean and the final diff has been reread.

## 6. Gate Audio Regression Before Merging

Compilation is not runtime verification, so decide whether the change requires
audio regression **before** merging.

Require it when the diff touches any of:

- `ios/` or `android/` sources;
- `src/specs/*.nitro.ts` or `nitrogen/generated/**`;
- `src/` code that changes recorder, player, listener, or permission behavior;
- `plugin/`, `NitroSound.podspec`, `android/build.gradle`, or a dependency
  that changes native linking.

The required rows are:

1. `$simulator-audio-e2e` on an explicitly selected iOS Simulator and Android
   emulator, for each touched platform, covering the recorder and player rows
   the diff implicates.
2. `$ios-audio-e2e` or `$android-audio-e2e` on a physical device for claims a
   simulator cannot exercise: interruptions and other apps' audio, background
   and lock-screen behavior, Bluetooth and route changes, and release-build
   behavior.

When a required row has not run, **stop without merging even if the PR is
otherwise clean**. Report the exact rows and hand back to the user; physical
devices and microphone permission need the user.

Exactly two things clear a row, and both are recorded on the PR before any
merge:

1. A run of that row with its result posted.
2. An explicit written waiver from the user in this conversation, naming the
   rows waived and the reason. Record it verbatim on the PR. Absence of an
   objection is not a waiver, and the loop must never grant one to itself.

A clean CI run is not a substitute: CI builds the example app but does not
record or play audio.

When regression is not required, say so explicitly in the final report and name
the paths that justify it. A change confined to documentation, Web-only code
with tests, repository automation, or agent workflows does not need device
regression.

## 7. Merge And Close The Loop

Immediately before merging, refetch the PR and confirm its head still equals the
clean reviewed SHA. Delete the temporary review-trigger comments the loop
posted, so the merged PR's conversation holds only real review. Squash-merge,
the only method the repository allows, with branch deletion. Never bypass a
protection rule or merge a stale, pending, or failing head.

After merge:

1. Confirm the PR state is `MERGED` and record the merge commit.
2. Confirm the linked issue closed; close it with a comment naming the merge
   commit when the closing keyword did not apply.
3. Confirm the remote branch was deleted when it lives in this repository; a
   fork's branch belongs to its owner. Delete the local branch after proving its
   tree is represented by the squash merge. A squash merge may require
   `git branch -D` after that proof; never use it for an unverified branch.
4. Switch to `main`, fetch `origin/main`, and run
   `git pull --ff-only --no-tags origin main` only when doing so cannot disturb
   other work.
5. Verify `HEAD` equals `origin/main` and the worktree is clean, and wait for
   the `main` CI runs on the merge commit.

## 8. Release, Only When Requested

When the request also asks for a release, follow `.claude/commands/release.md`
from an exact clean `main` whose CI passed: choose the version from the merged
changes, dispatch `.github/workflows/publish-package.yml`, then verify the npm
version, the tag, the GitHub Release, and the generated `CHANGELOG.md` entry.
Correct release-note prose with `$generate-doc` and land it through
`$loop-review-self`. Finish on `main` with `HEAD == origin/main` and a clean
worktree.

Report the PR, merge commit, final checks, review coverage, regression rows run
or waived, the closed issue, and any release evidence or remaining manual
follow-up.

## Stop Conditions

Stop without merging when a required choice lacks authority, the same finding
survives two fix attempts, an access blocker repeats under `$review-pr`'s
threshold, a required regression row has not run or been waived, or the exact
head cannot satisfy the clean gate. Report the concrete blocker; never describe
a pending or partially reviewed PR as clean.

After merge, stop the release phase when publication fails or its public
artifact cannot be verified. Preserve what succeeded and report the exact resume
point.
