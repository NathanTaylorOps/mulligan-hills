class_name MHVisualQuality
extends RefCounted
## Central mobile-first visual budget. Gameplay geometry and simulation never
## depend on these values; quality only changes presentation cost.

enum Tier { LOW, MEDIUM, HIGH, ULTRA }

static func automatic() -> Tier:
	if OS.has_feature("mobile"):
		# Conservative default. A later device benchmark can promote capable phones.
		return Tier.MEDIUM
	return Tier.HIGH

static func settings(tier: Tier) -> Dictionary:
	match tier:
		Tier.LOW:
			return {
				"terrain_detail": false,
				"mowing": true,
				"edge_accents": false,
				"tree_layers": 1,
				"decor_density": 0.35,
				"water_detail": false,
				"shadows": false,
			}
		Tier.MEDIUM:
			return {
				"terrain_detail": true,
				"mowing": true,
				"edge_accents": true,
				"tree_layers": 2,
				"decor_density": 0.65,
				"water_detail": true,
				"shadows": true,
			}
		Tier.ULTRA:
			return {
				"terrain_detail": true,
				"mowing": true,
				"edge_accents": true,
				"tree_layers": 3,
				"decor_density": 1.0,
				"water_detail": true,
				"shadows": true,
			}
		_:
			return {
				"terrain_detail": true,
				"mowing": true,
				"edge_accents": true,
				"tree_layers": 3,
				"decor_density": 0.85,
				"water_detail": true,
				"shadows": true,
			}

static func name_for(tier: Tier) -> String:
	return ["Low", "Medium", "High", "Ultra"][int(tier)]
