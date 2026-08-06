# Repository Guidelines

## Project Structure & Module Organization

- `src/`: TypeScript API (`index.tsx`, `index.web.tsx`) and Nitro spec in `src/specs/*.nitro.ts`.
- Native: `android/` (Kotlin + C++ adapter) and `ios/` (Swift). Generated bindings live under `nitrogen/` (c++/kotlin/swift) — do not edit.
- Example app: `example/` (Yarn workspace) for local testing on iOS/Android/Web.
- Plugin: `plugin/` Expo config plugin code. Tests: `src/__tests__/`.

## Build, Test, and Development Commands

- `yarn prepare`: Build library with bob and run Nitro codegen; required after changing specs and before publishing.
- `yarn nitrogen`: Regenerate native bindings from specs.
- `yarn typecheck`: TypeScript checks.
- `yarn lint`: ESLint + Prettier. Auto-fix with `yarn lint --fix`.
- `yarn test`: Jest (react-native preset).
- Example app: `yarn start`, `yarn ios`, `yarn android`, `yarn web` (proxied to `example/`).
- `yarn clean`: Remove build outputs (`lib/`, example and Android/iOS builds).

## Coding Style & Naming Conventions

- TypeScript with 2-space indent, single quotes, trailing commas (es5) — enforced by Prettier and ESLint (`eslint.config.mjs`).
- Naming: camelCase (vars/functions), PascalCase (classes/types). Use `.web.tsx` for web-specific entry.
- Public API lives in `src/`. Modify behavior via `src/specs/*.nitro.ts` and native implementations; never hand-edit `nitrogen/generated/**`.

## Testing Guidelines

- Framework: Jest with `react-native` preset. Place tests in `src/__tests__/*.test.ts(x)`.
- Add/adjust tests for new features and bug fixes; keep tests deterministic.
- Run locally with `yarn test`. Type safety is enforced by `yarn typecheck`.

## Commit & Pull Request Guidelines

- Conventional Commits enforced via commitlint (e.g., `feat: add playback speed`).
- Hooks (lefthook): pre-commit runs `eslint` and `tsc`; commit message is linted.
- PRs: include a clear description, linked issues, platform impact, and updated docs (e.g., `README.md`, `docs/MIGRATION.md`). If native changes, verify on both iOS and Android; update the `example/` app if behavior changes.

## Architecture Notes

- Bridge is implemented with `react-native-nitro-modules`. Define the surface in `src/specs/*.nitro.ts`, implement natively (Kotlin/Swift), then regenerate with `yarn nitrogen`/`yarn prepare`.
- Android/iOS permissions: verify microphone access during local testing (see example app configuration).

## AI Workflow & Skills

- Canonical cross-agent skills live in `.codex/skills/*/SKILL.md`; Claude Code discovery wrappers live in `.claude/skills/*/SKILL.md` and must point back to the canonical files.
- Route repository maintenance through `$nitro-sound-workflows`. Detailed command procedures live in `.claude/commands/` for PR review, audits, knowledge compilation, verification, E2E, releases, issue resolution, dependency upgrades, and commit/PR work.
- Use `$ios-audio-e2e` and `$android-audio-e2e` for device-backed audio claims. Compilation alone is not runtime verification.
- Use `$simulator-audio-e2e` for guarded Maestro recorder/player regression runs on explicitly selected iOS Simulators and Android emulators.
- Use `$rebase-main` to preserve staged, unstaged, untracked, ignored, and generated work during synchronization. Never use destructive reset/clean shortcuts.
- Use `$review-self` for a final independent pass and `$generate-doc` whenever public exports, Nitro specs, platform behavior, compatibility, or releases change.
- Internal workflow-only changes under `.claude/`, `.codex/`, `AGENTS.md`, or `knowledge/_claude-context/` stay local unless the user explicitly requests commit, push, PR, or merge.
- Install the repository Codex skills for automatic discovery with `.codex/scripts/install-skills.sh`.
