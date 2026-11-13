---
name: loop-review-self
description: 'Land a minor documentation, release-note, or repository-housekeeping change on main without a pull request: review it with review-self until two consecutive snapshots are clean, run the checks its paths require, then commit and push directly to main and verify the result.'
---

# Loop Review Self

Take a small change that is already written and land it on `main` by itself.
This skill owns exactly two phases: self-review until stable, then a direct
push. It opens no pull request, requests no external reviewer, releases no
package, and runs no device regression.

Use the branch → PR flow in `.claude/commands/commit.md` instead, then
`$review-pr`, whenever the change needs a PR.

## Qualifying Scope

The change qualifies only when every touched path is one of:

- user documentation: `README.md`, `docs/`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `issue_template.md`, and release-note prose in
  `CHANGELOG.md`;
- agent instructions and context: `AGENTS.md`, `CLAUDE.md`, and
  `knowledge/_claude-context/`;
- agent workflows: `.codex/skills/`, `.codex/scripts/install-skills.sh`,
  `.claude/skills/`, and `.claude/commands/`;
- repository housekeeping that ships no published artifact: `.gitignore`,
  `.editorconfig`, `.markdownlint.json`, `.vscode/`, and comment-only edits to
  files outside the excluded paths below.

Stop and hand the change to the PR flow when it touches anything else,
including: `src/` (public API, hooks, Web entry, and `src/specs/*.nitro.ts`),
`ios/`, `android/`, `nitrogen/` (generated bindings), `plugin/`, `example/`,
`e2e/`, `scripts/`, `.github/`, `package.json` (including its `version` field),
`yarn.lock`, `.yarn/`, `NitroSound.podspec`, `nitro.json`, `app.plugin.js`,
`index.ts`, lint, TypeScript, Babel, or Turbo configuration, or a
`CHANGELOG.md` entry cut by a release. A change to documented runtime behavior
also goes through a PR, because the docs must match the shipped code. Size is
not the test; the paths are. If the scope is ambiguous, ask rather than assume.

## Authority

An explicit `$loop-review-self` invocation authorizes, for the qualifying
scope only: in-scope fixes, the checks the touched paths require, and one
commit pushed directly to `main`. It is the explicit commit and push request
that the internal-workflow guard in `AGENTS.md` and `$nitro-sound-workflows`
requires, so agent-workflow-only changes do push under this skill. It does not
authorize a pull request, a package release, a manual deployment, a branch
rewrite, or any edit outside the change the user described.

Product code never lands this way: `CONTRIBUTING.md` keeps code changes on
topic branches and pull requests.

## 1. Establish The Target

1. Read `AGENTS.md`, `$nitro-sound-workflows`, and every convention file that
   applies to the changed paths.
2. Snapshot `git status --short --branch`. Preserve every pre-existing change
   that the task does not own, and never stash in this shared checkout.
3. Confirm the working tree is on `main` and that `main` is not behind
   `origin/main`. Fetch and fast-forward with `--ff-only --no-tags` when it is.
4. Run the qualifying-scope check above over `git status --short`. Stop here if
   anything falls outside it.

## 2. Review Until Clean

Run `$review-self` against the full working-tree diff and follow it as written:
fix every validated in-scope finding, rerun the verification the fix affects,
and recheck at the user's interval, or five minutes by default, until two
consecutive complete snapshots are clean. Any edit resets the count.

Keep loop state out of tracked files, and never emulate the interval with a
shell sleep loop.

## 3. Verify

Before committing, run the checks the touched paths require and record their
output. Install dependencies with `yarn install --immutable` first when
`node_modules` is missing. Every change runs at least:

```bash
git diff --check
yarn prettier --check <touched Markdown, JSON, and YAML files>
```

Also validate that every path, script, skill, and command the change mentions
exists. `package.json` defines `typecheck`, `lint`, `test`, `prepare`,
`nitrogen`, and `build:web`; reference no other script name.

Add what each path owns:

- `knowledge/_claude-context/` or a source it summarizes: follow
  `.claude/commands/compile-knowledge.md` and keep the context grounded in the
  current source.
- New or renamed skills: keep `.codex/scripts/install-skills.sh`, the routing
  in `.codex/skills/nitro-sound-workflows/SKILL.md`, and the skill list in
  `AGENTS.md` in sync, and give each Claude adapter a pointer back to its
  canonical file.
- Comment-only edits to JavaScript or TypeScript files: `yarn lint` and
  `yarn typecheck`.

Leave unrelated pre-existing failures alone and say so. A failing check on an
owned file blocks the push; fix it and return to review.

## 4. Push To Main

Stage only the files this task owns, write one English conventional commit
message with the `docs` or `chore` type and the scopes in
`.claude/commands/commit.md` (`skills` for agent workflows), and push to `main`.
One verified batch, not one commit per finding. Let the commitlint hook run;
never pass `--no-verify`.

## 5. Confirm

1. Verify `HEAD` equals `origin/main` and the worktree is clean, so the Source
   Control panel is left empty.
2. Every push to `main` runs `CI`, `CI - iOS`, `CI - Android`, `CI - Web`, and
   `deploy-web`. Wait for the runs on the pushed SHA and report their
   conclusions. A runner cancellation with no failed step is infrastructure,
   not a regression, but say which run it was.
3. Report the commit SHA, the files changed, the checks run with their results,
   the clean-count evidence, and the CI results.

## Stop Conditions

Stop without pushing, and report the concrete blocker, when the scope leaves
the qualifying list, a finding needs a decision or authority that is not
available, the same root finding survives two fix attempts, a required check
keeps failing, `main` cannot be fast-forwarded safely, or the push is rejected
by branch protection or a ruleset. A blocked result is never reported as clean.
