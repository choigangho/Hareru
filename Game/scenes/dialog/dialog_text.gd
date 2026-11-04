class_name DialogText
extends Control
## Screen-resolution text layer for the dialog dock (mock M-2): name, ruby line, meaning,
## typing cursor, "next" mark. Coordinates are 1280x720 (art x2). Positions match the mock.

const PH := Color8(150, 240, 150)
const PH_DIM := Color8(90, 170, 100)
const AMBER := Color8(250, 214, 120)
const CREAM := Color8(236, 222, 186)
const TEXT_X := 316
const TEXT_TOP := 594
const TEXT_W := 900
const SIZE := 26
const RUBY_SIZE := 16   # §9 minimum for helper text
const LINE_H := 48
const TEXT_BOX := Rect2(272, 572, 952, 116)  # dock text screen in screen px
const NAME_POS := Vector2(302, 544)

var runner: DialogueRunner


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


## Lays segments out into glyph runs: [{text, ruby, emph, x, y, w, start}] with wrapping.
static func layout(segs: Array, font: Font, width: float) -> Array:
	var out: Array = []
	var x := 0.0
	var y := 0.0
	var count := 0
	for seg in segs:
		var pieces: Array = [seg.base] if seg.ruby != "" else Array(seg.base.split(""))
		for p in pieces:
			var w := font.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
			if x + w > width and x > 0:
				x = 0
				y += LINE_H
			out.append({"text": p, "ruby": seg.ruby, "emph": seg.emph, "x": x, "y": y, "w": w, "start": count})
			x += w
			count += p.length()
	return out


func _draw() -> void:
	if runner == null or runner.current().is_empty() or runner.is_choice() and runner.main_text() == "":
		_draw_name()
		return
	var f := Fonts.gothic()
	_draw_name()
	var text := runner.main_text()
	var is_jp := runner.has_japanese()
	var col := PH if is_jp or runner.current().speaker != "독백" else CREAM
	var runs := layout(Ruby.parse(text), f, TEXT_W)
	var shown := int(runner.revealed)
	var asc := f.get_ascent(SIZE)
	var end := Vector2(TEXT_X, TEXT_TOP)
	for r in runs:
		if r.start >= shown:
			break
		var t: String = r.text
		var visible_n: int = min(t.length(), shown - r.start)
		var part := t.substr(0, visible_n)
		var c: Color = AMBER if r.emph else col
		var pos := Vector2(TEXT_X + r.x, TEXT_TOP + r.y + asc)
		draw_string(f, pos, part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, c)
		if r.emph:
			var pw := f.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
			draw_line(Vector2(pos.x, TEXT_TOP + r.y + SIZE + 7), Vector2(pos.x + pw, TEXT_TOP + r.y + SIZE + 7), AMBER, 2)
		if r.ruby != "" and visible_n == t.length():
			var rw := f.get_string_size(r.ruby, HORIZONTAL_ALIGNMENT_LEFT, -1, RUBY_SIZE).x
			draw_string(f, Vector2(pos.x + (r.w - rw) / 2.0, TEXT_TOP + r.y - 3), r.ruby, HORIZONTAL_ALIGNMENT_LEFT, -1, RUBY_SIZE, PH_DIM if not r.emph else AMBER)
		end = Vector2(TEXT_X + r.x + f.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x, TEXT_TOP + r.y)
	if runner.is_typing():
		draw_rect(Rect2(end.x + 4, end.y + 4, 12, 28), PH)
		return
	var last_y: float = runs.back().y if not runs.is_empty() else 0.0
	if is_jp:
		var my: float = TEXT_TOP + last_y + 42
		if runner.meaning_open:
			draw_string(f, Vector2(TEXT_X, my + f.get_ascent(24)), "(" + runner.meaning() + ")", HORIZONTAL_ALIGNMENT_LEFT, TEXT_W, 24, CREAM)
		else:
			draw_string(f, Vector2(TEXT_X, my + f.get_ascent(16)), "뜻 보기: 줄 누르기 / Tab", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PH_DIM)
	if not runner.is_choice():
		draw_colored_polygon(PackedVector2Array([Vector2(1196, 668), Vector2(1210, 668), Vector2(1203, 677)]), PH)


func _draw_name() -> void:
	if runner == null:
		return
	var n := runner.speaker_name()
	if n != "":
		var f := Fonts.gothic()
		draw_string(f, NAME_POS + Vector2(0, f.get_ascent(19)), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, CREAM)
