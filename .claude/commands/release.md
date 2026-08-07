# Release Package

Prepare, dispatch, and verify an npm release through the repository's manual
GitHub Actions workflow.

## Usage

```text
/release <patch|minor|major> [latest|next]
```

Publication requires explicit user authorization in the current request. A
request to prepare or review a release does not authorize dispatch.

## 1. Preflight

1. Read `AGENTS.md`, `package.json`, `CHANGELOG.md`,
   `.github/workflows/publish-package.yml`, and the latest published tag/release.
2. Require a clean `main` synchronized exactly with `origin/main` using a
   fast-forward-only update.
3. Confirm no merge, rebase, cherry-pick, or release operation is active.
4. Confirm required CI is green for the exact head.
5. Resolve the current npm version, proposed semantic version, dist-tag, and
   Git tag. Verify that the proposed npm version and tag do not already exist.
6. Review the full previous-release-to-head range and generate user-facing notes
   with `$generate-doc` rules.

Stop on version ambiguity, a dirty/divergent branch, failing checks, an existing
tag/version, or incompatible workflow permissions.

## 2. Verify Locally

Run `.claude/commands/verify-all.md`. Device runtime checks are required when the
release includes audio behavior changes that lack equivalent current evidence.
Inspect the package contents before publication and confirm generated bindings
match the declared Nitro versions.

## 3. Dispatch

After explicit confirmation of bump, dist-tag, and GitHub Release choice:

```bash
gh workflow run publish-package.yml \
  --repo hyochan/react-native-nitro-sound \
  -f version=<patch|minor|major> \
  -f tag=<latest|next> \
  -f create_release=<true|false>
```

Do not run `npm publish`, create tags, or push a release commit locally in
parallel. The workflow owns version bump, changelog update, tag, npm publication,
and optional GitHub Release.

## 4. Monitor And Verify

Follow the dispatched run to a terminal state. On success, verify:

- the workflow's published version;
- npm registry version and requested dist-tag;
- Git tag and pushed release commit;
- GitHub Release presence and prerelease status when requested;
- installation metadata and package contents.

On failure, inspect the exact job logs and report partial external state before
retrying. Never rerun a failed publication blindly; determine whether the npm
version or Git tag was already created.
