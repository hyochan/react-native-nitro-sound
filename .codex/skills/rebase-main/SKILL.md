---
name: rebase-main
description: Safely update local main from origin/main, rebase the current react-native-nitro-sound work branch, resolve conflicts without losing staged, unstaged, untracked, ignored, or generated work, and restore the original working-tree state. Use when asked to pull main, rebase onto main, or fix a stuck rebase.
---

# Rebase Main

Update `main`, rebase the work branch, and preserve all pre-existing work. Do
not commit, push, or force-push unless the user separately authorizes it.

## Establish State

1. Read `AGENTS.md` and record the current branch, `HEAD`, upstream, worktrees,
   staged changes, unstaged changes, untracked files, and relevant ignored local
   files.
2. Inspect `.git` state for an active rebase, merge, cherry-pick, revert, or
   bisect. Do not start a second operation.
3. Stop if detached, already on `main` for a rebase request, or the target base
   cannot be identified safely.
4. Use `origin/main` only after confirming both refs exist.

## Safeguard Work

If tracked or untracked changes exist, create one clearly named stash with
`--include-untracked`; never use `--all`. Record the stash object and verify the
worktree is clean. Fingerprint important ignored files and check that neither
destination tree tracks their exact paths before switching.

If a stale `.git/index.lock` or `.git/HEAD.lock` blocks progress, confirm its
age and verify no Git process owns it before removing only that exact lock. If
an earlier operation is active, inspect its head, target, todo, and conflicts;
continue or abort only when that preserves the recorded intent.

## Update And Rebase

1. Run `git fetch --prune origin`.
2. Check out `main` without overwriting ignored files.
3. Run `git merge --ff-only origin/main`. Stop on local/remote divergence; do
   not reset or create a merge commit.
4. Confirm `main` and `origin/main` resolve to the same commit.
5. Check out the recorded work branch with the same ignored-path guard.
6. Run `git rebase origin/main`.
7. For each conflict, inspect base, main, and work-branch intent. Regenerate
   `nitrogen/generated/**` through `yarn nitrogen` or `yarn prepare`; never pick
   a blanket side for generated output.

Never use `git reset --hard`, `git checkout --`, or `git clean` as recovery.

## Restore And Verify

Apply the safeguard stash with its index. Resolve restoration conflicts, then
compare staged, unstaged, untracked, and ignored state with the initial
snapshot. Drop only the named stash after restoration is exact.

Run `git status`, `git diff --check`, and the lightweight checks affected by
conflict resolution. Report old and new main/work heads. If a published branch
was rewritten, explain that a later `git push --force-with-lease` is required
but do not perform it without authorization.
