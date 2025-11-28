# Issue #741 Response - Audio codec properties not respected in release builds on iOS

## Root Cause Found & Fixed!

Thanks @felixspitzer for the detailed debugging logs! This confirms a **critical bug in the NitroModules nitrogen code generator**.

### Debug vs Release Comparison

| Property | Debug | Release |
|----------|-------|---------|
| `AVSampleRateKeyIOS` | `Optional(22050.0)` | `nil` |
| `AVNumberOfChannelsKeyIOS` | `Optional(2.0)` | `Optional(5.0)` (wrong!) |
| `AudioSamplingRate` | `Optional(22050.0)` | `Optional(-nan(0x30070002ade90))` |
| `AudioChannels` | `Optional(2.0)` | `nil` |

The values were being **corrupted or read incorrectly** in Release builds due to Swift compiler optimizations interacting badly with the C++ bridge code.

## Technical Analysis

Looking at the generated `nitrogen/generated/ios/swift/AudioSet.swift`, there was an inconsistency in how `std::optional` values are accessed:

**Pattern A (problematic in Release):**
```swift
var AVSampleRateKeyIOS: Double? {
    get {
        return self.__AVSampleRateKeyIOS.value  // ❌ Corrupted in Release
    }
}
```

**Pattern B (works correctly):**
```swift
var AudioSourceAndroid: AudioSourceAndroidType? {
    get {
        return self.__AudioSourceAndroid.has_value() ? self.__AudioSourceAndroid.pointee : nil  // ✅
    }
}
```

The `.value` accessor on `std::optional<double>` is not safe with Swift Release optimizations, while the explicit `has_value() ? .pointee : nil` pattern works correctly.

## Fix Applied

I've patched the generated `AudioSet.swift` file to use the safe pattern for all optional accessors. The following properties were fixed:

- `AVModeIOS`
- `AVEncodingOptionIOS`
- `AVFormatIDKeyIOS`
- `AVNumberOfChannelsKeyIOS`
- `AVSampleRateKeyIOS`
- `AudioQuality`
- `AudioChannels`
- `AudioSamplingRate`
- `AudioEncodingBitRate`

## Next Steps

1. **This fix will be included in the next release** of react-native-nitro-sound
2. I will also file an issue on the [NitroModules repository](https://github.com/mrousavy/nitro) to fix the code generator upstream

## For Users Who Need an Immediate Fix

If you can't wait for the next release, you can manually patch the file in your `node_modules`:

Edit `node_modules/react-native-nitro-sound/nitrogen/generated/ios/swift/AudioSet.swift` and replace all instances of:

```swift
return self.__PropertyName.value
```

With:

```swift
return self.__PropertyName.has_value() ? self.__PropertyName.pointee : nil
```

Then run `pod install` again.

---

**Related:**
- NitroModules: https://github.com/mrousavy/nitro
- This issue affects `std::optional` Swift bridging in Release builds
