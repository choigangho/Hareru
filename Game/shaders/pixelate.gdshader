shader_type canvas_item;
// Blocky mosaic over whatever is behind this rect (unreadable signs before they are learned).
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float block = 12.0;   // screen px per block

void fragment() {
	vec2 px = floor(FRAGCOORD.xy / block) * block + block * 0.5;
	COLOR = texture(screen_tex, px * SCREEN_PIXEL_SIZE);
}
