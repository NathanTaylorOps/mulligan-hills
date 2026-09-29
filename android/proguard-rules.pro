# ProGuard/R8 notes for the game module (android/build/proguard-rules.pro in the Godot custom build template).
# Godot 4 custom builds enable R8 for release only if you turn on minify in gradle.properties / build.gradle;
# default templates ship with minification OFF. If you turn it ON, keep the following. UNVERIFIED for 2026 templates.

# Godot plugin v2 entry points and annotated methods (Godot reads them by reflection)
-keep class org.godotengine.godot.plugin.** { *; }
-keep class * extends org.godotengine.godot.plugin.GodotPlugin { *; }
-keepclassmembers class * { @org.godotengine.godot.plugin.UsedByGodot <methods>; }

# Our plugin
-keep class com.mulliganhills.playintegrity.** { *; }

# Play Billing / Play Games / Play Integrity ship their own consumer rules; do not add blanket keeps for them.
# If a release-only crash mentions com.android.billingclient or com.google.android.gms.games, first try:
#   -keep class com.android.billingclient.** { *; }
