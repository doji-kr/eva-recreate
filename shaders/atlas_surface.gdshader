shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D original_atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 paint_color : source_color = vec4(0.3,0.35,0.28,1.0);
// UV window within the existing Tripo atlas, not a newly generated texture.
uniform vec4 atlas_region = vec4(0.584,0.171,0.035,0.04);
uniform float tiles_per_meter = 0.65;
uniform float texture_strength = 0.7;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 patch(vec2 coords) {
	// Mirror each repeat so the cropped atlas boundary does not create a seam.
	vec2 local_uv = 1.0 - abs(mod(coords,2.0)-1.0);
	return texture(original_atlas,atlas_region.xy+local_uv*atlas_region.zw).rgb;
}
void fragment() {
	vec3 weights = pow(abs(normalize(world_normal)),vec3(6.0));
	weights /= max(dot(weights,vec3(1.0)),0.0001);
	vec3 p = world_position * tiles_per_meter;
	vec3 sample_color = patch(p.yz)*weights.x + patch(p.xz)*weights.y + patch(p.xy)*weights.z;
	float worn_paint = clamp(dot(sample_color,vec3(0.299,0.587,0.114))/0.13,0.38,1.65);
	ALBEDO = paint_color.rgb * mix(1.0,worn_paint,texture_strength);
	ROUGHNESS = 0.97;
}
