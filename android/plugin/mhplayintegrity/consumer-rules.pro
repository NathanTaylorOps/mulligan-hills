# Keep the Godot plugin entry point and every method GDScript calls by name.
-keep class com.mulliganhills.playintegrity.MHPlayIntegrityPlugin { *; }
-keepclassmembers class com.mulliganhills.playintegrity.MHPlayIntegrityPlugin {
    @org.godotengine.godot.plugin.UsedByGodot <methods>;
}
