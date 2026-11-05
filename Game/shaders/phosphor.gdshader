shader_type canvas_item;
// Intro CRT (owner 2026-11-04, D-14): the city shows through the glass as green phosphor.
uniform vec3 dark : source_color = vec3(0.02, 0.07, 0.05);
uniform vec3 bright : source_color = vec3(0.42, 0.80, 0.52);
uniform float strength = 0.85;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 g = mix(dark, bright, pow(lum, 0.8));
	if (mod(FRAGCOORD.y, 4.0) < 2.0) {
		g *= 0.82;   // scan lines (2 art px)
	}
	COLOR = vec4(g, strength);
}
