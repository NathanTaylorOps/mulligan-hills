class_name MHWorldSurfaceIcon
extends RefCounted
## Temporary in-code material thumbnails for visual paint palettes.
## Final game assets replace these icons, not the interaction model.
## Nothing here adds geometry/grid lines to the course.

static func make(layer: int) -> Texture2D:
	var base: Color = Color(0.27, 0.44, 0.21)
	match layer:
		MHSplatMap.Layer.FAIRWAY: base = Color(0.36, 0.64, 0.23)
		MHSplatMap.Layer.FIRST_CUT: base = Color(0.31, 0.55, 0.21)
		MHSplatMap.Layer.GREEN: base = Color(0.50, 0.78, 0.30)
		MHSplatMap.Layer.FRINGE: base = Color(0.42, 0.68, 0.26)
		MHSplatMap.Layer.TEE: base = Color(0.46, 0.72, 0.29)
		MHSplatMap.Layer.BUNKER_SAND: base = Color(0.72, 0.66, 0.48)
		MHSplatMap.Layer.WATER: base = Color(0.12, 0.40, 0.70)
		MHSplatMap.Layer.PATH: base = Color(0.42, 0.40, 0.36)
		MHSplatMap.Layer.WASTE: base = Color(0.57, 0.49, 0.35)
		MHSplatMap.Layer.DIRT: base = Color(0.45, 0.32, 0.20)
	var img: Image = Image.create(42, 42, false, Image.FORMAT_RGBA8)
	for py: int in range(42):
		for px: int in range(42):
			var grain: float = float((px * 11 + py * 23 + px * py % 13) % 17) / 16.0
			var stripes: float = sin(float(px + py * 2) * 0.24) * 0.05
			var amt: float = (grain - 0.5) * 0.12 + stripes
			var color: Color = base.lightened(amt) if amt >= 0.0 else base.darkened(-amt)
			img.set_pixel(px, py, color)
	return ImageTexture.create_from_image(img)
