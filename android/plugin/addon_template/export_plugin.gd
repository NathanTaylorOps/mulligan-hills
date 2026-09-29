@tool
extends EditorPlugin
## Copy this folder to game/addons/MHPlayIntegrity/ and put the built AARs in bin/debug and bin/release.
## Mechanism follows Godot's Android plugin v2 pattern (EditorExportPlugin). UNVERIFIED against the pinned
## Godot version: confirm at https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html

const PLUGIN_NAME: String = "MHPlayIntegrity"
var _export_plugin: MHAndroidExportPlugin

func _enter_tree() -> void:
	_export_plugin = MHAndroidExportPlugin.new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null

class MHAndroidExportPlugin extends EditorExportPlugin:
	const NAME: String = "MHPlayIntegrity"

	func _get_name() -> String:
		return NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([NAME + "/bin/debug/" + NAME + "-debug.aar"])
		return PackedStringArray([NAME + "/bin/release/" + NAME + "-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.google.android.play:integrity:1.4.0"])
