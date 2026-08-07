---
name: nitro-sound-workflows
description: Use for react-native-nitro-sound repository work that should follow the project slash-command workflows for PR review, code audit, knowledge compilation, full verification, iOS or Android audio E2E, npm releases, issue resolution, dependency upgrades, commits, pushes, PRs, Nitro code generation, and native checks.
---

# Nitro Sound Workflows (Claude Code)

Read and follow `.codex/skills/nitro-sound-workflows/SKILL.md` as the canonical
shared operating contract, then read the matching `.claude/commands/*.md` file.

Map PR feedback and monitoring to the `$review-pr` skill. Map other
natural-language requests to `audit-code`,
`compile-knowledge`, `resolve-issue`, `verify-all`, `e2e-tests`, `release`,
`upgrade-deps`, or `commit`. Use the matching project skill under
`.claude/skills/` for documentation, platform E2E, rebase, funding, or
self-review work.

Where the canonical skill refers to `$skill-name`, use the same Claude skill or
read its `.claude/skills/<name>/SKILL.md` wrapper. Preserve its generated-code,
cross-platform, verification, and external-write safeguards exactly.
