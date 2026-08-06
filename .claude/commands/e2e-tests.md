# Audio E2E Tests

Verify the example app across build and runtime lanes. Use
`.codex/skills/ios-audio-e2e/SKILL.md` and
`.codex/skills/android-audio-e2e/SKILL.md` as the detailed platform procedures.
Use `.codex/skills/simulator-audio-e2e/SKILL.md` when virtual devices are
explicitly sufficient and physical devices must not be selected.

## Usage

```text
/e2e-tests [ios|android|web|all] [build-only]
```

An unqualified request targets iOS, Android, and Web. Separate build-only rows
from live runtime rows.

## Safety Gate

Before any live native recording, obtain explicit approval in the current run
and state the selected device and `sound.example` app. Use only short,
non-sensitive test audio. Platform builds, installation, launch, and permission
inspection may proceed without microphone capture.

## Common Preflight

```bash
git status --short --branch
yarn install --immutable
yarn prepare
yarn typecheck
yarn test
```

Preserve all existing changes and inspect regenerated bindings.

## Build Matrix

- **Web**: `yarn build:web`
- **Android**: `yarn turbo run build:android --cache-dir=.turbo/android`
- **iOS**: mirror `.github/workflows/ci-ios.yml`, including Pods and the
  `SoundExample` simulator build

Record unavailable SDKs or machines as `BLOCKED`.

## Runtime Matrix

Exercise the smallest complete set for the change:

| Flow                | Required evidence                                                      |
| ------------------- | ---------------------------------------------------------------------- |
| Permission          | grant/deny result and recoverable retry behavior                       |
| Record              | resolved URI/path, active state, increasing millisecond callback       |
| Pause/resume record | time pauses and resumes without duplicate instance                     |
| Stop record         | terminal state, listener cleanup, non-empty app-owned file             |
| Playback            | increasing position, sensible duration, audible or instrumented output |
| Seek/speed/volume   | requested value takes effect without invalid state                     |
| Playback end        | exactly one terminal callback and cleanup                              |
| Rapid switch        | no crash, double-settlement, or leaked player across test loop         |
| Hooks               | unmount/remount cleans listeners and native resources                  |
| Web                 | permission, MediaRecorder format, Blob URL playback, timer cleanup     |

Run interruption, route changes, backgrounding, focus loss, process death, or
remote streaming only when the requested behavior touches them. These rows need
explicit device/browser evidence.

## Result Vocabulary

Use `BUILD PASS/FAIL`, `RUNTIME PASS/FAIL`, and `BLOCKED` per platform. Include
device/browser versions, tested screen/API, logs or callback evidence, created
artifact cleanup, and every untested row. Never upgrade a build pass, UI tap, or
partial callback trace to a runtime pass.
