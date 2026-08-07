# Verify All

Run the repository's complete practical health check while preserving any
pre-existing working-tree changes.

## 1. Snapshot

```bash
git status --short --branch
node --version
yarn --version
```

Read `AGENTS.md` and current CI workflows. Record the initial diff so generated
changes produced by verification are not mistaken for user edits.

## 2. Deterministic Checks

```bash
yarn install --immutable
yarn typecheck
yarn lint
yarn test --maxWorkers=2 --coverage
yarn prepare
yarn build:web
git diff --check
```

After `yarn prepare`, inspect changes under `nitrogen/generated/**`. Do not
revert them. A generated diff means the checked-in bindings were stale and is a
verification finding.

## 3. Native Builds

Run the exact build procedures from:

- `.github/workflows/ci-android.yml`
- `.github/workflows/ci-ios.yml`

Android requires the configured SDK and JDK 17. iOS requires macOS, the workflow
Xcode version or a consciously verified replacement, Bundler, CocoaPods, and
the example workspace. Report unavailable prerequisites as `BLOCKED`, not pass.

## 4. Runtime Matrix

Compilation does not verify audio behavior. When the requested change affects
recording, playback, permissions, listeners, audio session/focus, lifecycle, or
concurrency, invoke `.claude/commands/e2e-tests.md` and the platform skill after
the microphone approval gate.

## 5. Report

Report each command, result, duration when useful, generated diffs, Android/iOS
build status, Web build status, runtime rows, and blockers. Include the final
`git status` and do not call the repository healthy when a required lane failed
or was silently skipped.
