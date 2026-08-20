shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec3 snow_color : source_color = vec3(0.95, 0.96, 0.98);
uniform lowp float snow_amount : hint_range(0.0,1.0) = 0.0;
uniform lowp vec3 season_tint : source_color = vec3(1.0);
uniform float snow_max_height = 14.0;

varying lowp float v_height;
varying flat lowp float v_snow_factor;

void vertex() {
	v_height = VERTEX.y;
	float h = clamp(v_height / snow_max_height, 0.0, 1.0);
	float t = clamp((h - 0.55) * 2.222222, 0.0, 1.0);
	t = t * t * (3.0 - 2.0 * t);
	v_snow_factor = t;
}

void fragment() {
	lowp vec3 base = COLOR.rgb * season_tint;
	lowp float snow = snow_amount * v_snow_factor;
	ALBEDO = mix(base, snow_color, snow);
	ROUGHNESS = 0.92;
}
