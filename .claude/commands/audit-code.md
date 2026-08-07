# Audit Code

Audit the selected react-native-nitro-sound surface against its public API,
Nitro contract, platform implementations, tests, examples, docs, and current
toolchain requirements.

## Usage

```text
/audit-code [path|api|ios|android|web|all]
```

An audit is read-only unless the user also asks for fixes.

## Evidence Order

1. Read `AGENTS.md` and `.codex/skills/nitro-sound-workflows/SKILL.md`.
2. Resolve the requested paths and inspect their history when intent is unclear.
3. Read `src/specs/*.nitro.ts`, `src/index.tsx`, Web implementation, hooks,
   Swift, Kotlin, tests, example screens, README, FAQ, package metadata, and CI
   that apply.
4. For latest Nitro, React Native, Xcode, Android, or browser requirements,
   verify official primary documentation rather than relying on memory.

## Audit Lenses

- Public exports, types, defaults, units, errors, and backward compatibility
- Spec-to-generated-to-Swift/Kotlin wiring and codegen freshness
- Promise settlement, listener add/remove behavior, cleanup, idempotency, and
  rapid start/stop concurrency
- Recorder/player state machines, seek, speed, volume, and playback completion
- iOS permission, AVAudioSession, interruption, route, and lifecycle behavior
- Android permission, MediaRecorder/MediaPlayer, audio focus, lifecycle, and ABI
  build behavior
- Web MediaRecorder support, object URL cleanup, timers, and browser fallbacks
- Hooks cleanup and React lifecycle behavior
- Unit tests, example coverage, device evidence, docs, migration notes, and CI
- Generated-file policy, release safety, secret handling, and workflow permissions

## Validate Findings

Every finding must identify the affected path, concrete failure mode, evidence,
severity, and smallest safe remediation. Confirm the finding against current
code and reject speculative or cosmetic observations. Distinguish:

- confirmed defect;
- coverage or verification gap;
- documentation drift;
- current external compatibility risk;
- blocked runtime claim requiring a device.

## Output

List findings in severity order, then verification gaps and a concise clean-area
summary. If there are no actionable findings, say so and state which platforms
or runtime lanes were not exercised. Do not modify code unless the user asked
for implementation.
