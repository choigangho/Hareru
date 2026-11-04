class_name ReaderText
extends Control
## Paper text of the reader at screen resolution (A-4: paper = smooth mincho). Mock M-3.

const INK := Color8(48, 36, 30)
const INK_SOFT := Color8(110, 92, 72)
const KEY_LABEL := Color8(60, 46, 36)
const HEAD_CENTER_X := 658
const HEAD_BASE := 300
const HEAD_SIZE := 60
const EX_X := 456
const EX_BASE := 392
const EX_SIZE := 24
const TR_BASE := 428
# key hit areas: art keys are 104x48 px on screen; areas grown to 64 high (§9), 24 px apart
const KEY_RECTS := [Rect2(292, 548, 104, 64), Rect2(420, 548, 104, 64), Rect2(548, 548, 104, 64), Rect2(676, 548, 108, 64)]
const KEY_NAMES := ["모르겠음", "애매함", "알고있음", "쉬움"]

var model: ReaderModel
var bank: WordBank
var mosaic: ColorRect


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()
	if mosaic and model:
		var c := model.clarity()
		mosaic.visible = model.phase in [ReaderModel.Phase.INSERT, ReaderModel.Phase.SCAN] and c < 0.999
		(mosaic.material as ShaderMaterial).set_shader_parameter("clarity", c)


func _draw() -> void:
	if model == null or model.phase == ReaderModel.Phase.FINISHED or model.phase == ReaderModel.Phase.INSERT:
		return
	var w := bank.word(model.word_id())
	if w.is_empty():
		return
	var reps := int(model.session.records.get(model.word_id(), {}).get("reps", 0))
	var s := bank.sense(model.word_id(), reps)
	var read := model.phase in [ReaderModel.Phase.READ, ReaderModel.Phase.STAMP]
	var m := Fonts.mincho()
	var g := Fonts.gothic()
	# headword (reading only after the handle)
	var hw := m.get_string_size(w.term, HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_SIZE).x
	var hx := HEAD_CENTER_X - hw / 2.0
	draw_string(m, Vector2(hx, HEAD_BASE), w.term, HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_SIZE, INK)
	if read:
		if w.reading != w.term:
			var rw := g.get_string_size(w.reading, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(g, Vector2(HEAD_CENTER_X - rw / 2.0, HEAD_BASE - HEAD_SIZE - 2), w.reading, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK_SOFT)
		draw_string(g, Vector2(hx + hw + 12, HEAD_BASE - 4), s.meaning, HORIZONTAL_ALIGNMENT_LEFT, 220, 18, INK_SOFT)
	# example sentence (readings only after reading)
	var x := float(EX_X)
	for seg in Ruby.parse_braces(s.example):
		var bw := m.get_string_size(seg.base, HORIZONTAL_ALIGNMENT_LEFT, -1, EX_SIZE).x
		draw_string(m, Vector2(x, EX_BASE), seg.base, HORIZONTAL_ALIGNMENT_LEFT, -1, EX_SIZE, INK)
		if read and seg.ruby != "":
			var rw2 := g.get_string_size(seg.ruby, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(g, Vector2(x + (bw - rw2) / 2.0, EX_BASE - EX_SIZE - 2), seg.ruby, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK_SOFT)
		x += bw
	if read:
		var tr: Dictionary = s.translation
		var tx := float(EX_X)
		for part in [[tr.before, false], [tr.answer, true], [tr.after, false]]:
			var pw := g.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(g, Vector2(tx, TR_BASE), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK_SOFT)
			if part[1]:
				draw_line(Vector2(tx, TR_BASE + 4), Vector2(tx + pw, TR_BASE + 4), INK_SOFT, 1.5)
			tx += pw
		for i in 4:
			var r: Rect2 = KEY_RECTS[i]
			var label := "%d %s" % [i + 1, KEY_NAMES[i]]
			var lw := g.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(g, Vector2(r.position.x + (r.size.x - lw) / 2.0, r.position.y + 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, KEY_LABEL)
