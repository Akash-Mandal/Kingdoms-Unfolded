shader_type spatial;
// Terrain shader: biome vertex color + seasonal snow + season tint.
// Vertex Y (local) is used as elevation so snow settles on high ground.

uniform vec3 snow_color = vec3(0.95, 0.96, 0.98);
uniform float snow_amount = 0.0;          // 0..1
uniform vec3 season_tint = vec3(1.0);    // per-season ground tint
uniform float snow_max_height = 14.0;    // elevation at which snow is full

varying float v_height;

void vertex() {
	v_height = VERTEX.y;
}

void fragment() {
	vec3 base = COLOR.rgb * season_tint;
	float h = clamp(v_height / snow_max_height, 0.0, 1.0);
	float snow = clamp(snow_amount * (0.25 + h * 1.25), 0.0, 1.0);
	ALBEDO = mix(base, snow_color, snow);
	ROUGHNESS = 0.92;
}