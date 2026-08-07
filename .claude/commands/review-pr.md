# Review Pull Request

Use the canonical `$review-pr` workflow in
`.codex/skills/review-pr/SKILL.md` for the supplied PR number or URL.

Claude Code must follow the same exact-head discovery, finding classification,
thread reply/resolution, Nitro verification matrix, `$review-self` fallback,
five-minute monitoring, and two-clean-snapshot completion gate. Use Claude's
real scheduled wake-up mechanism when available; never emulate the loop with a
sleeping shell process.
