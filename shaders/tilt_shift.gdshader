shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float focus_center : hint_range(0.0, 1.0) = 0.52;
uniform float focus_half_width : hint_range(0.0, 0.5) = 0.22;
uniform float falloff : hint_range(0.01, 0.5) = 0.26;
uniform float tilt : hint_range(-0.5, 0.5) = 0.0;
uniform float blur_amount : hint_range(0.0, 5.0) = 3.5;

void fragment() {
	// A sharp focus strip with a gradual transition to defocused foreground/background.
	float distance_to_focus = abs(SCREEN_UV.y - focus_center - (SCREEN_UV.x - 0.5) * tilt);
	float blur = smoothstep(focus_half_width, focus_half_width + falloff, distance_to_focus);
	COLOR = vec4(textureLod(screen_texture, SCREEN_UV, blur * blur_amount).rgb, 1.0);
}
