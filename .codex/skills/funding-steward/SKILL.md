---
name: funding-steward
description: Maintain react-native-nitro-sound funding links, GitHub Funding configuration, Buy Me a Coffee and PayPal calls to action, supporter acknowledgements, and transparent maintainer updates. Use when editing sponsor copy or assets, checking funding-link consistency, or drafting or publishing supporter-facing updates.
---

# Funding Steward

Treat funding as a transparent community-support surface and keep every link and
claim consistent across the repository and live profiles.

## Canonical Repository Surfaces

- GitHub Funding: `.github/FUNDING.yml`
- README support section: `README.md` under `Help Maintenance`
- Buy Me a Coffee account: `hyochan`
- PayPal destination: `https://paypal.me/dooboolab`

Verify the live destination before changing canonical values. Do not introduce
OpenCollective, GitHub Sponsors, Patreon, or another platform unless the user
confirms the project uses it.

## Workflow

1. Establish the requested surface: funding configuration, README CTA, badge or
   image, supporter acknowledgement, or a live update.
2. Read `AGENTS.md`, the current funding config, and every README occurrence.
3. Draft evidence-backed copy before any public write. Keep the tone warm,
   specific, and builder-to-builder.
4. For live profile or update edits, use the user's existing signed-in browser
   session only after the user authorizes publication. Hand sign-in and any
   payment/account verification back to the user.
5. Verify the saved public URL and then update repository links if the canonical
   destination changed.

## Guardrails

- Never expose account emails, payout details, tokens, balances, private donor
  data, or browser authentication state.
- Never promise release dates, response times, or sponsor benefits that are not
  documented and operational.
- Do not imply that a past donor opted into a new program.
- Distinguish recurring sponsorship, one-time support, and non-financial
  contribution accurately.
- Keep funding changes local unless commit, push, PR, or publication authority
  is explicit.

## Update Pattern

Use a concise structure unless the user provides exact copy:

1. Thank supporters and state the concrete milestone.
2. List shipped maintenance, compatibility, docs, CI, or issue-triage work.
3. Explain what support enables without inflating impact.
4. Name near-term work without overcommitting.
5. Link the repository and the intended funding destination.

After an edit, check Markdown rendering, image accessibility text, HTTPS links,
and consistency between `.github/FUNDING.yml` and README.
