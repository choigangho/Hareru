shader_type canvas_item;
// The paper on the reader glass (front reader v13). What is printed (a SubViewport) is laid on
// the reclined glass (a trapezoid); the top and bottom ends roll away over a cylinder and get
// dark (owner 2026-11-04). Also: the paper sliding in, the scan blur before reading, and the
// scan bar's light and shade. Same curl maths as PaperScroll.row_source.
uniform sampler2D content : filter_linear;
uniform vec2 content_size = vec2(520.0, 1600.0);
uniform float content_h = 400.0;
uniform float scroll = 0.0;
uniform float curl = 38.0;
uniform float top_y = 112.0;
uniform float bot_y = 446.0;
uniform vec4 edges = vec4(352.0, 838.0, 334.0, 854.0);   // top left, top right, bottom left, bottom right
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float insert = 0.0;      // px of paper still above the glass (sliding down from the feeder)
uniform float paper_len = 334.0; // length of the sheet (≥ the glass)
uniform float clarity = 1.0;     // scan: 0 blurred .. 1 sharp, below ex_top only
uniform float ex_top = 0.0;
uniform float scan_y = -1.0;     // screen row of the scan bar, < 0 = parked
uniform vec3 paper = vec3(0.969, 0.949, 0.839);
uniform vec3 shade_col = vec3(0.118, 0.078, 0.071);

void fragment() {
	vec2 p = rect_pos + UV * rect_size;
	float y = p.y;
	if (y < top_y || y >= bot_y) {
		discard;
	}
	float view = bot_y - top_y;
	float t = (y - top_y) / view;
	float xl = mix(edges.x, edges.z, t);
	float xr = mix(edges.y, edges.w, t);
	if (p.x < xl || p.x > xr) {
		discard;
	}
	float d = y - top_y;
	float src;
	float lit = 1.0;
	if (d < curl) {
		float a = curl * asin(min(1.0, (curl - d) / curl));
		src = scroll + curl - a;
		lit = cos(a / curl);
	} else if (d > view - curl) {
		float a = curl * asin(min(1.0, (d - (view - curl)) / curl));
		src = scroll + view - curl + a;
		lit = cos(a / curl);
	} else {
		src = scroll + d;
	}
	src += insert;
	if (src > paper_len) {
		discard;   // below the sheet's bottom edge: bare glass
	}
	float u = (p.x - xl) / (xr - xl) * content_size.x;
	vec3 col = paper;
	if (src >= 0.0 && src < content_h) {
		vec2 q = vec2(u, src);
		if (src >= ex_top && clarity < 0.999) {
			float cell = floor(mix(12.0, 2.0, clarity));
			q = (floor(q / cell) + 0.5) * cell;
		}
		col = texture(content, q / content_size).rgb;
	}
	if (mod(d, 8.0) < 1.0) {
		col *= 0.985;
	}
	if (scan_y >= 0.0) {
		float dd = abs(y - scan_y);
		col += vec3(0.275, 0.431, 0.235) * max(0.0, 1.0 - dd / 34.0);
		col = mix(col, vec3(0.118, 0.094, 0.102), 0.235 * clamp((dd - 50.0) / 150.0, 0.0, 1.0));
	}
	col = mix(col, shade_col, 0.95 * pow(1.0 - lit, 0.55));
	COLOR = vec4(col, 1.0);
}
