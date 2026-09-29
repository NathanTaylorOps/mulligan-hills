shader_type spatial;
render_mode cull_disabled;
// Far LOD: Y-axis billboard. Turns the silhouette to face the camera around the vertical axis.
// UNVERIFIED on device: MODELVIEW_MATRIX override with MultiMesh instances.

uniform vec3 brush_pos = vec3(0.0, 0.0, 0.0);
uniform float brush_radius = 12.0;
uniform float brush_strength = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	VERTEX.x *= sx;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z, 0.0),
		MODEL_MATRIX[1],
		vec4(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z, 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	NORMAL = vec3(0.0, 1.0, 0.0);
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
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
