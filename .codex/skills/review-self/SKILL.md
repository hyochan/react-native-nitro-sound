---
name: review-self
description: Independently review and improve the current react-native-nitro-sound implementation, working-tree changes, commit range, or pull request; fix actionable in-scope gaps; rerun path-specific verification; and optionally recheck until stable. Use when asked for self-review, final verification, or monitoring of current work.
---

# Review Self

Review the full current target, validate findings against repository evidence,
fix in-scope defects, and prove the result with the smallest complete checks.

## Preserve Scope And Authority

- Treat invocation as authority for local inspection, in-scope fixes, and
  verification only.
- Do not commit, push, edit a PR, post comments, merge, deploy, release, or
  change live state unless the original request already authorized it.
- Preserve pre-existing user changes and never sweep-stage or discard unrelated
  files.
- Stop for a material product choice, irreversible action, or scope expansion.

## Establish The Target

1. Reconstruct the requested outcome and acceptance criteria.
2. Use an explicit PR, range, branch, or path when supplied. Otherwise include
   the current base-to-head diff plus staged, unstaged, and untracked overlays.
3. Read `AGENTS.md`, `$nitro-sound-workflows`, and every instruction or source
   file applicable to the changed paths.
4. For a PR, resolve its actual base, exact head SHA, checks, reviews, and
   unresolved threads. Do not assume the current local branch matches it.

## Run A Review Round

1. Re-snapshot the full target from disk.
2. Check requirement completeness, public API wiring, TypeScript/Web/native
   parity, promise settlement, listener lifecycle, concurrency, error cleanup,
   permissions, audio session/focus transitions, generated-code integrity,
   backward compatibility, tests, examples, and docs.
3. Validate each finding against current code. Reject style-only churn,
   duplicates, and unrelated improvements.
4. Fix all validated in-scope findings as one coherent batch. Regenerate Nitro
   bindings through the documented generator only.
5. Re-read the final diff and run `git diff --check` plus the path matrix from
   `$nitro-sound-workflows`.
6. For runtime audio changes, use `$ios-audio-e2e` and/or
   `$android-audio-e2e`; compilation alone cannot close a runtime finding.
7. Use subagents only when the user explicitly requests delegated or parallel
   review work.

If this skill is the fallback for `.claude/commands/review-pr.md`, run exactly
one round for the supplied head and return findings, fixes, checks, and a clean
or blocked result. Leave reviewer requests, GitHub replies, thread resolution,
and polling with the calling workflow.

## Optional Stability Rechecks

Run the first round immediately. If the user asks for ongoing monitoring, use a
real recurring wake-up mechanism at five-minute intervals and carry the goal,
target, head/tree fingerprints, check IDs, feedback IDs, findings, and authority
in compact state. Never emulate monitoring with `sleep`, a shell loop, `nohup`,
or an abandoned background process.

Declare stability after two complete clean snapshots separated by a recheck.
Pending CI or reviewer automation is neither clean nor failed. Stop and report
the exact blocker when a decision is required, the same finding survives two
fix attempts, an environment failure blocks three rounds, or unchanged external
state remains pending for about an hour.

Finish with the target reviewed, findings fixed or rejected with evidence,
files changed, checks run, runtime rows exercised, and remaining blockers.
