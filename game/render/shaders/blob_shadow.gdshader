shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft dark blob quad laid on the ground under trees. Cheap stand-in for real shadows.

uniform float max_alpha : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float r = length(UV * 2.0 - vec2(1.0));
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.2, 1.0, r)) * max_alpha;
}
