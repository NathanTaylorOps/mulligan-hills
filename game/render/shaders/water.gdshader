shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
// Flat water plane. Cheap fake ripples in the normal from two sine sums; no textures, no screen reads.

uniform vec3 shallow_color : source_color = vec3(0.16, 0.48, 0.62);
uniform vec3 deep_color : source_color = vec3(0.04, 0.20, 0.34);
uniform float alpha_value : hint_range(0.0, 1.0) = 0.88;
uniform float wave_amount : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = world_pos.xz;
	float nx = sin(p.x * 0.9 + t * 1.3) * 0.5 + sin(p.y * 1.7 - t * 0.9) * 0.3;
	float nz = cos(p.y * 1.1 + t * 1.1) * 0.5 + cos(p.x * 1.9 + t * 0.7) * 0.3;
	vec3 n = normalize(vec3(nx * 0.12 * wave_amount, 1.0, nz * 0.12 * wave_amount));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color, shallow_color, fres);
	ROUGHNESS = 0.1;
	SPECULAR = 0.6;
	ALPHA = alpha_value;
}
