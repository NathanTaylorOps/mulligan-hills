shader_type spatial;
render_mode cull_back;
// Lit low-poly tree. Vertex colour is albedo (multiplied by the MultiMesh instance colour).
// Dither fade: fragments near brush_pos (world space, XZ distance) are discarded with an
// interleaved-gradient-noise pattern. brush_strength 0 disables the effect.

uniform vec3 brush_pos = vec3(0.0, 0.0, 0.0);
uniform float brush_radius = 12.0;
uniform float brush_strength = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (brush_strength > 0.0) {
		float d = distance(world_pos.xz, brush_pos.xz);
		float fade = (1.0 - smoothstep(brush_radius * 0.4, brush_radius, d)) * brush_strength;
		float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (fade > noise) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.0;
}
