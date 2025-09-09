-keep class com.margelo.nitro.sound.** { *; }

# HybridObject-based classes are created via reflection; don't shrink/obfuscate
// Keep any class deriving from Nitro's HybridObject base
-keep class * extends com.margelo.nitro.core.HybridObject { *; }
// Backwards-compat: if older Nitro exposed an interface, keep those too
-keep class * implements com.margelo.nitro.HybridObject { *; }
 

# Silence warnings for nitro internals
-dontwarn com.margelo.nitro.**
