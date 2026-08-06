# Upgrade Dependencies

Bump `react-native-nitro-sound` dependencies — especially `react-native-nitro-modules`, `nitrogen`, and audio-adjacent libs — to the latest compatible versions and verify the example app. Commit, push, or open a PR only when the user explicitly requests publication.

## Usage

```text
/upgrade-deps [--safe | --minor | --major]
```

- `--safe` (default): patch-level only (x.y.Z)
- `--minor`: minor + patch (x.Y.Z)
- `--major`: include major bumps (requires manual review)

## Workflow

### 1. Snapshot Current State

```bash
git status --short --branch
git fetch origin main
git checkout main
git merge --ff-only origin/main
git checkout -b chore/deps-bump-$(date +%Y%m%d)
node -p "Object.assign({}, require('./package.json').dependencies, require('./package.json').devDependencies, require('./package.json').peerDependencies)"
```

Stop before switching when local changes are not safely preserved. Use
`$rebase-main` when updating an existing work branch.

### 2. Check Latest Versions

Check registry for these in particular:

- `react-native-nitro-modules`
- `nitrogen`
- `react-native-builder-bob`
- `@react-native-community/slider`
- `react-native` (devDep, for test matrix)
- `expo` (devDep)

```bash
for p in react-native-nitro-modules nitrogen react-native-builder-bob @react-native-community/slider; do
  echo "$p: $(npm view $p version)"
done
```

### 3. Apply Bumps

Edit `package.json`:

- **ALWAYS keep `react-native-nitro-modules` version in `devDependencies` and the floor in `peerDependencies` aligned.** If we bump devDep to `0.36.0`, peer range should be `>=0.36.0`.
- Keep `nitrogen` version in lockstep with `react-native-nitro-modules`.

Then:

```bash
yarn install --mode=update-lockfile
yarn install --immutable
```

Update the lockfile intentionally, then require a subsequent immutable install
to pass.

### 4. Regenerate Nitrogen (if nitro-modules / nitrogen changed)

```bash
yarn prepare
```

Review the diff under `nitrogen/generated/` — regenerated output should be committed in its own commit.

### 5. Verify

```bash
yarn typecheck
yarn lint
yarn test
yarn build:web
yarn turbo run build:android --cache-dir=.turbo/android
# Mirror .github/workflows/ci-ios.yml for the iOS example build.
```

### 6. Optional: Commit in Logical Chunks

Run this section only when the user explicitly asked for a commit.

```bash
# 1. package.json + yarn.lock
git add package.json yarn.lock example/package.json
git commit -m "chore(deps): bump <pkg> to <version>

🤖 AI-assisted maintenance."

# 2. Regenerated nitrogen (if any)
git add nitrogen/generated/
git commit -m "chore(nitro): regenerate nitrogen output

🤖 AI-assisted maintenance."

# 3. Native source follow-ups (only if the bump required source changes)
git add ios/ android/
git commit -m "chore(native): align with new nitro-modules API

🤖 AI-assisted maintenance."
```

### 7. Optional: Push + PR

Run this section only when the user explicitly asked to publish the branch.

```bash
git push -u origin HEAD
gh pr create --title "chore(deps): bump <headline>" --body "$(cat <<'EOF'
## Summary
Dependency bumps targeting latest compatible versions.

## Bumps
- react-native-nitro-modules: <old> → <new>
- nitrogen: <old> → <new>
- react-native-builder-bob: <old> → <new>
- @react-native-community/slider: <old> → <new>

## Test plan
- [ ] `yarn typecheck` passes
- [ ] `yarn lint` passes
- [ ] iOS example builds (Debug, sim)
- [ ] Android example builds (Debug)

🤖 AI-assisted maintenance.
EOF
)" --label "dependencies"
```

## Rules

- **Never** bump `react-native` or `expo` major versions as part of a routine dep-bump PR. Those get their own dedicated PR with a migration checklist.
- If a bump breaks the build, **don't force it**. Pin back to the last working version, open an issue describing the incompatibility, and label it `👷‍♀️ build`.
- If `react-native-nitro-modules` has a breaking change, follow the corresponding upstream upgrade guide before re-generating nitrogen.
