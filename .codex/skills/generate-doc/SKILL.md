---
name: generate-doc
description: Create or update react-native-nitro-sound API documentation, examples, migration notes, FAQ entries, changelog or release notes, and compiled AI context. Use when public exports, Nitro specs, native behavior, compatibility requirements, installation steps, or releases need documentation.
---

# Generate Nitro Sound Documentation

Ground every statement in the current repository and keep all documented
platforms aligned with the implementation.

## Choose The Surface

- Update `README.md` for installation, requirements, API usage, public examples,
  and high-level migration guidance.
- Update `docs/FAQ.md` for reproducible troubleshooting and platform-specific
  workarounds.
- Update `CHANGELOG.md` only when preparing or correcting release history.
- Update `knowledge/_claude-context/context.md` after meaningful API, native,
  dependency, or maintenance-workflow changes.
- Update example screens when documentation depends on behavior users must be
  able to run.

Do not create a new documentation surface when an existing one has the right
audience.

## Collect Evidence

Read, in order:

1. `AGENTS.md` and the user's requested change.
2. `package.json`, `nitro.json`, and the current Git tag or intended release.
3. `src/index.tsx`, `src/index.web.tsx`, hooks, and `src/specs/*.nitro.ts`.
4. Relevant `ios/*.swift` and `android/src/main/**/*.kt` implementations.
5. Existing README, FAQ, changelog, issue, and PR language that the edit affects.
6. CI and release workflows when documenting build or publication behavior.

Use package metadata for versions. Verify current registry, platform, or
toolchain facts from authoritative sources when they may have changed. Never
infer a released version from an unreleased branch or generated file.

## Write Accurate Examples

- Use imports actually exported by `src/index.tsx`.
- Show asynchronous recorder/player loading states where the API requires them.
- Keep record and playback positions in milliseconds.
- Include microphone permission and native setup only where the platform needs
  it.
- Distinguish iOS, Android, and Web behavior instead of implying false parity.
- Prefer a short runnable example over disconnected snippets.
- Link issues or releases for non-obvious compatibility guidance.
- Never document hand-edits to `nitrogen/generated/**` as a supported fix.

## Prepare Release Documentation

Derive the change range from the previous published tag through the exact target
head. Group notes by user impact rather than commit mechanics. Exclude generated
file churn, version-only noise, and internal workflow edits unless they change a
maintainer-facing contract.

When the automated deploy workflow will update `CHANGELOG.md`, prepare or test
the release-note input without duplicating the generated entry. Confirm the tag
format and version behavior from `.github/workflows/publish-package.yml` before
naming links.

## Validate

Run the checks relevant to the examples and files changed:

```bash
yarn typecheck
yarn lint
yarn test
git diff --check
```

Add `yarn build:web` for Web examples and a platform build for native setup or
behavior claims. Re-read rendered Markdown, verify anchors and links, and report
any platform behavior that was documented but not exercised.
