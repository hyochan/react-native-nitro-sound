# Changelogs

## [0.2.19] — 2026-08-07


### 🔧 Maintenance Release

This release contains dependency updates and internal improvements only.

### 📦 Dependency Updates

2 dependency bump(s) — see the [full diff](https://github.com/hyochan/react-native-nitro-sound/compare/0.2.18...0.2.19) for details.

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.18...0.2.19

---


## [0.2.18] — 2026-08-07

```sh
yarn add react-native-nitro-sound@0.2.18
```

### 🐛 Reliability fixes

- Harden Android `MediaPlayer` ownership and cleanup so stale callbacks from replaced players cannot settle newer playback operations. ([#838](https://github.com/hyochan/react-native-nitro-sound/pull/838))
- Use the current iOS Bluetooth HFP audio-session category option consistently across recorder and player setup. ([#838](https://github.com/hyochan/react-native-nitro-sound/pull/838))
- Remove obsolete Android external-storage permission requests and consolidate microphone permission handling in the example app. ([#838](https://github.com/hyochan/react-native-nitro-sound/pull/838))

### ⚙️ Compatibility and tooling

- Move the supported iOS build baseline to Xcode 26.0+ and align CI, CocoaPods setup, and compatibility documentation.
- Align development and example tooling with Node 22, Yarn 4.18, React Native 0.86.2, and Nitro 0.36.5. The published peer dependency now requires `react-native-nitro-modules >=0.36.5`.

### 🧪 Verification

- Expand native and Web unit coverage and add guarded Simulator audio regression flows for recorder and player state transitions.
- The iOS Simulator lane covered record, pause/resume, stop, play, pause/resume, and stop. Bluetooth routing, interruptions, backgrounding, route changes, audio focus, physical-device-only behavior, and audible fidelity remain outside Simulator coverage.

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.17...0.2.18

---


## [0.2.17] — 2026-08-05

```sh
yarn add react-native-nitro-sound@0.2.17
```

### 🐛 Bug Fixes

- return the recording URI from repeated stopRecorder calls ([#837](https://github.com/hyochan/react-native-nitro-sound/pull/837))
- bound channel count by what the input route supports ([#836](https://github.com/hyochan/react-native-nitro-sound/pull/836))

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.16...0.2.17

---


## [0.2.16] — 2026-08-05

```sh
yarn add react-native-nitro-sound@0.2.16
```

### 🐛 Bug Fixes

- support android.resource:// URIs in startPlayer ([#834](https://github.com/hyochan/react-native-nitro-sound/pull/834))
- force 16 KB page-size alignment for libNitroSound.so ([#833](https://github.com/hyochan/react-native-nitro-sound/pull/833))
- range-validate recording settings to survive corrupted values ([#832](https://github.com/hyochan/react-native-nitro-sound/pull/832))
- make stopRecorder idempotent ([#831](https://github.com/hyochan/react-native-nitro-sound/pull/831))
- make pause and resume reliable for playback ([#830](https://github.com/hyochan/react-native-nitro-sound/pull/830))

### 📦 Dependency Updates

24 dependency bump(s) — see the [full diff](https://github.com/hyochan/react-native-nitro-sound/compare/0.2.15...0.2.16) for details.

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.15...0.2.16

---


## [0.2.15] — 2026-05-22

```sh
yarn add react-native-nitro-sound@0.2.15
```

### 🔧 Maintenance Release

This release contains dependency updates and internal improvements only.

### 📦 Dependency Updates

7 dependency bump(s) — see the [full diff](https://github.com/hyochan/react-native-nitro-sound/compare/0.2.14...0.2.15) for details.

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.14...0.2.15

---


## [0.2.14] — 2026-04-25

```sh
yarn add react-native-nitro-sound@0.2.14
```

### 🐛 Bug Fixes

- use HEAD^ to find previous tag before version bump

### 📦 Dependency Updates

1 dependency bump(s) — see the [full diff](https://github.com/hyochan/react-native-nitro-sound/compare/0.2.13...0.2.14) for details.

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.13...0.2.14

---


## [0.2.13] — 2026-04-17

```sh
yarn add react-native-nitro-sound@0.2.13
```

### 🔧 Maintenance Release

This release contains dependency updates and internal improvements only.

---

**Full Changelog**: https://github.com/hyochan/react-native-nitro-sound/compare/0.2.12...0.2.13

---


[Check out releases](https://github.com/hyochan/react-native-nitro-sound/releases)
