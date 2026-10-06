class_name MHStarCartProfiles
extends RefCounted
## Data-driven presentation profiles for celebrity/pro parody carts.
## Gameplay eligibility is owned by MHGameSession; these profiles can never enable carts.

const DEFAULT_PROFILE: Dictionary = {
	"body": "golf_cart",
	"scale_x10": 10,
	"park_offset_x10": 35,
	"park_offset_z10": 20,
	"behavior": "park_nearby",
}

const PROFILES: Dictionary = {
	# Add parody-specific skins here. Renderer behavior stays generic.
	"lion_black_suv": {
		"body": "suv",
		"scale_x10": 13,
		"park_offset_x10": 42,
		"park_offset_z10": 24,
		"behavior": "park_nearby_upside_down",
	},
}


static func profile_for(skin: String) -> Dictionary:
	var out: Dictionary = DEFAULT_PROFILE.duplicate(true)
	if PROFILES.has(skin):
		for key: Variant in (PROFILES[skin] as Dictionary).keys():
			out[key] = (PROFILES[skin] as Dictionary)[key]
	out["skin"] = skin
	return out


static func validate_profile(profile: Dictionary) -> bool:
	if not ["golf_cart", "suv", "roadster", "utility", "limo"].has(str(profile.get("body", ""))):
		return false
	if int(profile.get("scale_x10", 0)) < 5 or int(profile.get("scale_x10", 0)) > 30:
		return false
	return ["park_nearby", "park_nearby_upside_down"].has(str(profile.get("behavior", "")))


static func body_size(profile: Dictionary) -> Vector3:
	var scale: float = float(int(profile.get("scale_x10", 10))) / 10.0
	if str(profile.get("body", "golf_cart")) == "suv":
		return Vector3(1.8, 1.05, 3.4) * scale
	return Vector3(1.25, 0.75, 2.0) * scale


static func park_offset(profile: Dictionary) -> Vector3:
	return Vector3(float(int(profile.get("park_offset_x10", 35))) / 10.0, 0.0,
		float(int(profile.get("park_offset_z10", 20))) / 10.0)
