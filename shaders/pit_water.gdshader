shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.035, 0.20, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.15, 0.48, 0.68, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.32, 0.85, 0.90, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.55;
uniform float wave_scale : hint_range(0.1, 3.0) = 0.8;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.18;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec2 ripple_center = vec2(0.0, -2.0);
varying vec3 water_position;
varying vec3 surface_normal;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

// Moving, domain-warped cellular ridges approximate focused underwater light.
vec2 cell_hash(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)),
		dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

float caustic_edge(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = cell_hash(cell + offset);
			vec2 point = 0.5 + 0.34 * sin(seed * 6.283185 + t * 0.48);
			float distance_sq = dot(offset + point - local, offset + point - local);
			second = max(nearest, min(second, distance_sq));
			nearest = min(nearest, distance_sq);
		}
	}
	return sqrt(second) - sqrt(nearest);
}

void fragment() {
	vec2 p = water_position.xz * wave_scale;
	float t = TIME * wave_speed;
	float a = p.x * 0.72 + p.y * 1.25 + t;
	float b = p.x * -1.1 + p.y * 0.63 - t * 0.73;
	float swell = sin(a) * 0.6 + sin(b) * 0.4;
	vec2 flow = (water_position.xz - ripple_center) * wave_scale * 0.7;
	flow += vec2(sin(p.y * 0.85 + t * 0.35), cos(p.x * 0.76 - t * 0.29)) * 0.42;
	flow += vec2(sin(p.y * 1.9 - p.x * 0.6 + t * 0.2),
		cos(p.x * 1.7 + p.y * 0.5 + t * 0.26)) * 0.14;
	float edge = caustic_edge(flow + vec2(t * 0.06, -t * 0.04), t);
	float edge2 = caustic_edge(flow * 1.31 + vec2(4.7, 9.2) - t * 0.025, -t * 0.7);
	float aa = max(fwidth(edge) * 0.75, 0.008);
	float fine = 1.0 - smoothstep(0.018, 0.045 + aa, edge);
	float halo = 1.0 - smoothstep(0.025, 0.19 + aa, edge);
	float secondary = 1.0 - smoothstep(0.012, 0.045 + max(fwidth(edge2), 0.008), edge2);
	float top = smoothstep(0.5, 0.9, surface_normal.y);
	float shimmer = 0.72 + 0.28 * sin(p.x * 0.65 + p.y * 0.47 + t * 0.6);
	float glints = clamp((fine * 0.65 + halo * 0.22 + secondary * 0.24) * shimmer, 0.0, 1.0) * top;
	vec2 slope = vec2(0.72, 1.25) * cos(a) * 0.6 + vec2(-1.1, 0.63) * cos(b) * 0.4;

	vec3 wave_normal = normalize(vec3(-slope.x * normal_strength, 1.0, -slope.y * normal_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(surface_normal, wave_normal, top)), 0.0)).xyz);
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	float tone = clamp(0.4 + swell * 0.18 + fresnel * 0.35, 0.0, 1.0);
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, tone);
	ALBEDO = mix(water, highlight_color.rgb, glints * highlight_strength * 0.7);
	EMISSION = water * 0.24 + highlight_color.rgb * glints * highlight_strength * 0.5;
	ROUGHNESS = 0.26;
	SPECULAR = 0.65;
}
