shader_type canvas_item;
// QR-like mosaic over the example sentence behind this rect (CORE_LOOP §2 scan).
// Each block measures how much ink is inside it and becomes a flat ink/paper cell.
// clarity 0 → big blocks, 1 → no effect.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float clarity = 0.0;
uniform vec2 rect_size = vec2(400.0, 40.0);
uniform vec3 paper = vec3(0.969, 0.949, 0.839);  // paper_on_mat #F7F2D6
uniform vec3 ink = vec3(0.30, 0.25, 0.22);

void fragment() {
	if (clarity >= 0.999) {
		discard;
	}
	float block = floor(mix(12.0, 3.0, clarity));
	vec2 px = UV * rect_size;
	vec2 cell0 = floor(px / block) * block;
	float cov = 0.0;
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec2 p = cell0 + (vec2(float(x), float(y)) + 0.5) * block / 4.0;
			vec2 suv = SCREEN_UV + (p - px) * SCREEN_PIXEL_SIZE;
			vec3 c = texture(screen_tex, suv).rgb;
			cov += step(dot(c, vec3(0.333)), 0.6);
		}
	}
	cov /= 16.0;
	float on = step(0.08, cov);
	// sharper text → lighter cells, so the sentence "comes through" as clarity rises
	vec3 col = mix(paper, mix(ink, paper, clarity * 0.55), on * clamp(0.55 + cov, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
