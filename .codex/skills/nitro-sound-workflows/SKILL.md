---
name: nitro-sound-workflows
description: Use for react-native-nitro-sound repository work that should follow the project workflows for PR review, code audit, knowledge compilation, full verification, iOS or Android audio E2E, npm releases, issue resolution, dependency upgrades, commits, pushes, PRs, Nitro code generation, and native cross-platform checks.
---

# Nitro Sound Workflows

Route natural-language maintenance requests to the repository's canonical
workflow documents and enforce the shared native-module safeguards below.

## Read The Source Of Truth

Before editing, read root `AGENTS.md` and the instructions nearest the changed
path. Use these files as primary evidence:

- Public API: `src/index.tsx`, `src/index.web.tsx`, and `src/specs/*.nitro.ts`
- Native behavior: `ios/*.swift` and `android/src/main/**/*.kt`
- Generated bindings: `nitrogen/generated/**`
- Build and release behavior: `package.json` and `.github/workflows/*.yml`
- User documentation: `README.md`, `docs/*.md`, and `CHANGELOG.md`
- Workflow details: `.claude/commands/*.md`

Do not restate a rule when one of those files already defines it precisely.

## Route The Request

Read and follow the matching command file:

- PR feedback, CI findings, or review monitoring: `$review-pr`; the legacy
  slash-command adapter is `.claude/commands/review-pr.md`
- Broad code and API audit: `.claude/commands/audit-code.md`
- Rebuild compact AI context: `.claude/commands/compile-knowledge.md`
- Resolve a GitHub issue: `.claude/commands/resolve-issue.md`
- Full repository health check: `.claude/commands/verify-all.md`
- Device-backed audio regression: `.claude/commands/e2e-tests.md`
- Stable or prerelease npm publication: `.claude/commands/release.md`
- Dependency upgrade: `.claude/commands/upgrade-deps.md`
- Commit, push, or open a PR: `.claude/commands/commit.md`

Use `$ios-audio-e2e` or `$android-audio-e2e` when the request targets one
native platform. Use `$simulator-audio-e2e` for repeatable virtual-device audio
regression flows that must explicitly avoid physical phones. Use
`$generate-doc` for API, migration, FAQ, changelog, or
release documentation. Use `$review-self` for an independent final pass and
`$rebase-main` for branch synchronization.

## Preserve The Nitro Contract

- Treat `src/specs/*.nitro.ts` as the native contract. Update the spec first
  when the exposed HybridObject surface changes.
- Never hand-edit `nitrogen/generated/**`. Regenerate with `yarn nitrogen` or
  run the complete build/codegen flow with `yarn prepare`, then inspect the
  generated diff.
- Keep TypeScript, Web, Swift, and Kotlin behavior aligned unless the public
  documentation explicitly identifies a platform limitation.
- Preserve millisecond units for record and playback event positions.
- Check listener registration, removal, promise settlement, cleanup, and
  recorder/player state transitions for every behavior change.
- Verify microphone permission and audio-session/focus behavior for recording
  changes. Treat background and interruption claims as device-backed claims.
- Preserve user changes. Never discard unrelated generated output, local
  settings, or untracked files.

## Select Verification By Path

Always run `git diff --check`, then select the smallest complete matrix:

- TypeScript/hooks/Web: run `yarn typecheck`, `yarn test`, and `yarn lint`.
  Also run `yarn build:web` when Web behavior changes.
- Nitro spec or generated bindings: `yarn prepare`, inspect all generated
  changes, then run typecheck, tests, and lint.
- Swift/iOS: run the iOS build procedure in `.github/workflows/ci-ios.yml`; use
  `$ios-audio-e2e` for runtime behavior.
- Kotlin/Android: run the Android build procedure in
  `.github/workflows/ci-android.yml`; use `$android-audio-e2e` for runtime
  behavior.
- Cross-platform public behavior: verify iOS, Android, and Web or explicitly
  report every untested platform.
- Documentation/workflows only: validate referenced paths and commands, check
  Markdown structure, and run the affected lightweight checks.

Do not claim a runtime pass from compilation alone.

## Guard External Writes

Internal workflow changes under `.claude/`, `.codex/`, `AGENTS.md`, or
`knowledge/_claude-context/` stay local unless the user explicitly requests a
commit, push, PR, or merge.

Before any GitHub write, resolve the exact repository, issue or PR number, and
current head. Keep public issue, PR, review, release, and commit prose in clear
English unless the user explicitly requests another language. Do not reply to
or resolve a review thread until the finding is fixed or disproved with current
repository evidence.

Before a release, require explicit publication authority, a clean and current
`main`, successful required checks, an unused version/tag, and the manual
workflow defined in `.github/workflows/publish-package.yml`.
