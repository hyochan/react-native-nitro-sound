-keep class com.margelo.nitro.sound.** { *; }

# HybridObject-based classes are created via reflection; don't shrink/obfuscate
-keep class * implements com.margelo.nitro.HybridObject { *; }
-keepclassmembers class * implements com.margelo.nitro.HybridObject { *; }

# Silence warnings for nitro internals
-dontwarn com.margelo.nitro.**
