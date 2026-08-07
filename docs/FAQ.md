# FAQ

## Swift 6 compile error: `function type mismatch … has_value` (#718)

If Xcode fails with errors similar to `function type mismatch, declared as '@convention(method) (__ObjC.std.__1.optional<>) -> Swift.Bool'` and duplicate symbols for `has_value`, you are running into the Swift 6 compiler bug tracked in [issue #718](https://github.com/hyochan/react-native-nitro-sound/issues/718). The bug affects Apple toolchains shipped with Xcode **16.4 and earlier** when compiling the generated Nitrogen bindings.

**Recommended fix: upgrade to Xcode 26.0 or newer.** Xcode 16.4 is still in the affected range, so it is not a sufficient baseline for this package. The repository CI currently verifies Xcode 26.3. After upgrading:

1. Delete `node_modules`, `ios/Pods`, and the Xcode DerivedData folder.
2. Reinstall dependencies (`yarn install`) and run `pod install --clean-install` inside `ios`.
3. Build again with the updated Xcode.

Should problems persist after the upgrade, please attach your full build log and toolchain versions when commenting on the issue.
