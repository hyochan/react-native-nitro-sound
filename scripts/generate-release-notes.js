#!/usr/bin/env node
/**
 * Generates structured, user-facing release notes from git history.
 *
 * Usage:
 *   node scripts/generate-release-notes.js <new-version>
 *
 * Output: markdown printed to stdout, suitable for a GitHub Release body.
 *
 * Sections produced (only non-empty sections are included):
 *   ⚡️ Breaking Changes
 *   🐛 Bug Fixes
 *   ✨ New Features
 *   ⚡ Performance
 *   📦 Dependency Updates  (aggregated count — no spam)
 *
 * Conventional-commit prefixes used for categorisation:
 *   fix: / fix(scope):  → Bug Fixes
 *   feat: / feat(scope): → New Features
 *   perf:              → Performance
 *   BREAKING CHANGE / !: → Breaking Changes
 *   chore(deps) / "bump X from Y to Z" → Dependencies
 *   everything else    → silently omitted from the body
 */

'use strict';

const { execSync } = require('child_process');

const newVersion = process.argv[2];
if (!newVersion) {
  console.error('Usage: node scripts/generate-release-notes.js <version>');
  process.exit(1);
}

const REPO = 'hyochan/react-native-nitro-sound';

// ─── 1. Resolve previous tag ─────────────────────────────────────────────────
let prevTag;
try {
  // HEAD is not yet tagged at generation time, so look for the most recent tag
  prevTag = execSync('git describe --tags --abbrev=0', { stdio: ['pipe', 'pipe', 'pipe'] })
    .toString()
    .trim();
} catch {
  // Fallback: first commit
  prevTag = execSync('git rev-list --max-parents=0 HEAD').toString().trim().slice(0, 7);
}

// ─── 2. Collect commits since previous tag ───────────────────────────────────
const SEP = '|||';
const rawLog = execSync(
  `git log ${prevTag}..HEAD --pretty=format:"%H${SEP}%s${SEP}%an${SEP}%b" --no-merges`
)
  .toString()
  .trim();

const commits = rawLog
  .split('\n')
  .filter(Boolean)
  .map((line) => {
    const [sha, subject, author, ...bodyParts] = line.split(SEP);
    return {
      sha: sha.slice(0, 7),
      subject: (subject || '').trim(),
      author: (author || '').trim(),
      body: bodyParts.join('').trim(),
    };
  });

// ─── 3. Categorise ───────────────────────────────────────────────────────────
const cats = {
  breaking: [],
  bugFix:   [],
  feature:  [],
  perf:     [],
  deps:     [],
};

for (const c of commits) {
  const s = c.subject;

  // Breaking change markers
  if (/BREAKING[ -]CHANGE/i.test(s) || /^[a-z]+(\([^)]+\))?!:/.test(s)) {
    cats.breaking.push(c);
    continue;
  }

  // Dependency bumps (dependabot / renovate style)
  if (/^chore\(deps(-dev)?\)/.test(s) || /^build\(deps\)/.test(s) || /bump .+ from .+ to /i.test(s)) {
    cats.deps.push(c);
    continue;
  }

  if (/^fix[:(]/.test(s))  { cats.bugFix.push(c);  continue; }
  if (/^feat[:(]/.test(s)) { cats.feature.push(c); continue; }
  if (/^perf[:(]/.test(s)) { cats.perf.push(c);    continue; }

  // ci, docs, chore, refactor, test → omit from user-facing notes
}

// ─── 4. Formatting helpers ────────────────────────────────────────────────────

/** Strip conventional-commit prefix and return clean title. */
function cleanTitle(subject) {
  return subject
    .replace(/^(fix|feat|perf|ci|docs|refactor|chore|build)(\([^)]+\))?!?:\s*/i, '')
    .replace(/\s*\(#\d+\)\s*$/, '')
    .trim();
}

/** Extract " ([#123](...)) " link from subject if a PR number is present. */
function prLink(subject) {
  const m = subject.match(/\(#(\d+)\)\s*$/);
  return m
    ? ` ([#${m[1]}](https://github.com/${REPO}/pull/${m[1]}))`
    : '';
}

function renderSection(title, items) {
  if (!items.length) return '';
  let out = `### ${title}\n\n`;
  for (const c of items) {
    out += `- ${cleanTitle(c.subject)}${prLink(c.subject)}\n`;
  }
  return out + '\n';
}

// ─── 5. Build output ──────────────────────────────────────────────────────────
const hasUserFacingChanges =
  cats.breaking.length + cats.bugFix.length + cats.feature.length + cats.perf.length > 0;

let body = '';

// Install snippet
body += `## Installation\n\n`;
body += `\`\`\`sh\nnpm install react-native-nitro-sound@${newVersion}\n`;
body += `# or\nyarn add react-native-nitro-sound@${newVersion}\n\`\`\`\n\n`;

if (!hasUserFacingChanges) {
  body += `### 🔧 Maintenance Release\n\n`;
  body += `This release contains dependency updates and internal improvements only.\n\n`;
} else {
  body += renderSection('⚡️ Breaking Changes', cats.breaking);
  body += renderSection('🐛 Bug Fixes',        cats.bugFix);
  body += renderSection('✨ New Features',      cats.feature);
  body += renderSection('⚡ Performance',       cats.perf);
}

if (cats.deps.length) {
  body += `### 📦 Dependency Updates\n\n`;
  body += `${cats.deps.length} dependency bump(s) — see the [full diff](https://github.com/${REPO}/compare/${prevTag}...${newVersion}) for details.\n\n`;
}

body += `---\n\n`;
body += `**Full Changelog**: https://github.com/${REPO}/compare/${prevTag}...${newVersion}\n`;

process.stdout.write(body);
