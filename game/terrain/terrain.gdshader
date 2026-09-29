shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// One flat 33x33 vertex grid mesh (x,z in cell units, y = 0) is shared by all chunks.
// Each chunk has its own material with:
//   height_tex: RG8, 35x35 texels (chunk 33x33 vertices + 1 texel border for normals).
//               value = (height_mm + 32768) as 16 bit: R = high byte, G = low byte.
//   splat_tex0..2 : RGBA8, same 35x35 layout. Layer L is in texture L / 4, channel L % 4 (see MHSplatMap):
//               tex0 = rough, fairway, first_cut, green; tex1 = fringe, tee, bunker_sand, water;
//               tex2 = path, waste, dirt, (unused, always 0).
// Vertex (i, j) of the chunk reads texel (i + 1, j + 1). Neighbouring chunks read identical
// texels for shared edge vertices, so there are no cracks (no LOD in Phase 0, no skirts needed).

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D splat_tex0 : filter_linear, repeat_disable;
uniform sampler2D splat_tex1 : filter_linear, repeat_disable;
uniform sampler2D splat_tex2 : filter_linear, repeat_disable;
uniform float cell_size_m = 1.0;
uniform float tex_size = 35.0;
uniform vec4 col_rough : source_color = vec4(0.22, 0.42, 0.16, 1.0);
uniform vec4 col_fairway : source_color = vec4(0.36, 0.62, 0.25, 1.0);
uniform vec4 col_first_cut : source_color = vec4(0.30, 0.55, 0.21, 1.0);
uniform vec4 col_green : source_color = vec4(0.45, 0.75, 0.32, 1.0);
uniform vec4 col_fringe : source_color = vec4(0.40, 0.68, 0.28, 1.0);
uniform vec4 col_tee : source_color = vec4(0.42, 0.72, 0.30, 1.0);
uniform vec4 col_bunker_sand : source_color = vec4(0.85, 0.78, 0.55, 1.0);
uniform vec4 col_water : source_color = vec4(0.20, 0.42, 0.70, 1.0);
uniform vec4 col_path : source_color = vec4(0.62, 0.58, 0.52, 1.0);
uniform vec4 col_waste : source_color = vec4(0.70, 0.62, 0.45, 1.0);
uniform vec4 col_dirt : source_color = vec4(0.45, 0.33, 0.22, 1.0);

varying vec2 splat_uv;

float decode_h_mm(ivec2 t) {
	vec4 c = texelFetch(height_tex, t, 0);
	float hi = floor(c.r * 255.0 + 0.5);
	float lo = floor(c.g * 255.0 + 0.5);
	return hi * 256.0 + lo - 32768.0;
}

void vertex() {
	ivec2 t = ivec2(int(VERTEX.x + 0.5), int(VERTEX.z + 0.5)) + ivec2(1, 1);
	float hc = decode_h_mm(t);
	float hl = decode_h_mm(t + ivec2(-1, 0));
	float hr = decode_h_mm(t + ivec2(1, 0));
	float hu = decode_h_mm(t + ivec2(0, -1));
	float hd = decode_h_mm(t + ivec2(0, 1));
	NORMAL = normalize(vec3(hl - hr, 2.0 * cell_size_m * 1000.0, hu - hd));
	VERTEX = vec3(VERTEX.x * cell_size_m, hc * 0.001, VERTEX.z * cell_size_m);
	splat_uv = (vec2(t) + vec2(0.5)) / tex_size;
}

void fragment() {
	vec4 a = texture(splat_tex0, splat_uv);
	vec4 b = texture(splat_tex1, splat_uv);
	vec4 c = texture(splat_tex2, splat_uv);
	float total = max(a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a + c.r + c.g + c.b, 0.001);
	vec3 col = a.r * col_rough.rgb + a.g * col_fairway.rgb + a.b * col_first_cut.rgb + a.a * col_green.rgb
		+ b.r * col_fringe.rgb + b.g * col_tee.rgb + b.b * col_bunker_sand.rgb + b.a * col_water.rgb
		+ c.r * col_path.rgb + c.g * col_waste.rgb + c.b * col_dirt.rgb;
	ALBEDO = col / total;
	ROUGHNESS = 1.0;
}
