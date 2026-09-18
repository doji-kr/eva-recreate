shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 internal_resolution = vec2(640.0, 480.0);
uniform float color_levels = 31.0;
void fragment() {
	vec2 cell = floor(SCREEN_UV * internal_resolution);
	vec2 uv = (cell + 0.5) / internal_resolution;
	vec3 color = textureLod(screen_texture, uv, 0.0).rgb;
	// A small ordered dither preserves dark painted detail in the reduced palette.
	float pattern = mod(cell.x, 2.0) * 2.0 + mod(cell.y, 2.0);
	float dither = (pattern - 1.5) / (color_levels * 8.0);
	color = floor(clamp(color + dither, 0.0, 1.0) * color_levels + 0.5) / color_levels;
	COLOR = vec4(color, 1.0);
}
