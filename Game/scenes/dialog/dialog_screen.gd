class_name DialogScreen
extends Node2D
## Dialog over the lab (mock M-2): dock + portrait CRT in art pixels, text on a screen layer.
## Keys: Enter/Space or click outside the line = next (finishes typing first),
## Tab or pressing the line = Korean meaning (pressing it again = next),
## Up/Down/1-9 + Enter = choice.

const ART := "res://art/"
const DOCK_Y := 264
const PORTRAIT_CRT_POS := Vector2(6, 246)
const PORTRAIT_POS := Vector2(17, 252)
const PORTRAITS := {
	"주임": {"기본": "chief_default", "미소": "chief_smile", "반짝": "chief_glint", "당황": "chief_flustered",
		"난감": "chief_troubled", "울컥": "chief_teary", "진지": "chief_serious", "뿌듯": "chief_proud"},
	"주인공": {"기본": "hero_default", "멍": "hero_daze", "뻘짓": "hero_goof", "놀람": "hero_surprised",
		"한심": "hero_meh", "귀찮": "hero_meh", "민망": "hero_awkward", "진지": "hero_serious"},
}
const CHOICE_X := 820
const CHOICE_Y := 330
const CHOICE_GAP := 76
const CHOICE_SIZE := Vector2(420, 64)

var runner := DialogueRunner.new()
var lab: LabScreen
var portrait: Sprite2D
var text: DialogText
var ui: CanvasLayer
var choice_boxes: Array = []
var choice_focus := 0
var scene_key := ""
var light: int = LabScreen.LightState.BEFORE_LAMP
var leak_fixed := false
var closeup := ""
var closeup_layer: Node2D   # dim + paper between the lab and the dock (memo mock: dim 150, x2 at 220,100)
const CLOSEUPS := {"memo": ["closeups/memo_closeup_kana.png", Vector2(220, 100)]}
var bucket_full := false
var typewriter: CanvasLayer   # open while the line asks for the name (mock M-5b)
var name_edit: LineEdit
var _lines: Array = []
var _start_after := ""


## The scene starts when the screen enters the tree, so listeners connected to `runner`
## in between (the day director) also hear cues and directions on the first lines.
func setup(scene_lines: Array, key := "", start_after := "") -> void:
	scene_key = key
	_lines = scene_lines
	_start_after = start_after


func _ready() -> void:
	lab = LabScreen.new()
	add_child(lab)
	lab.set_light(light)
	lab.bucket_full = bucket_full
	lab.set_leak_fixed(leak_fixed)
	lab.layers.hint.visible = false  # the "next task" dot belongs to free lab time, not dialog
	closeup_layer = Node2D.new()
	add_child(closeup_layer)
	set_closeup(closeup)
	_sprite("ui/ui_dialog_dock.png", Vector2(0, DOCK_Y))
	_sprite("ui/ui_dialog_portrait_crt.png", PORTRAIT_CRT_POS)
	portrait = _sprite("portraits/chief_default.png", PORTRAIT_POS)
	_sprite("ui/ui_dialog_scanlines_96.png", PORTRAIT_POS)
	ui = CanvasLayer.new()
	add_child(ui)
	text = DialogText.new()
	text.runner = runner
	ui.add_child(text)
	runner.finished.connect(func(): EventBus.dialog_finished.emit(scene_key))
	runner.load_scene(_lines, _start_after)
	_refresh()


func _process(delta: float) -> void:
	if not runner.is_done():
		runner.tick(delta)


func set_closeup(n: String) -> void:
	closeup = n
	if closeup_layer == null:
		return
	for c in closeup_layer.get_children():
		c.queue_free()
	if not CLOSEUPS.has(n):
		return
	var dim := ColorRect.new()
	dim.color = Color8(10, 8, 12, 150)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closeup_layer.add_child(dim)
	var paper := Sprite2D.new()
	paper.texture = load(ART + CLOSEUPS[n][0])
	paper.centered = false
	paper.position = CLOSEUPS[n][1]
	# 200x120 art shown at 400x240 on screen = scale 1 inside the x2 world
	closeup_layer.add_child(paper)


func _unhandled_input(e: InputEvent) -> void:
	if runner.is_done() or runner.hold or typewriter:
		return
	if runner.is_choice():
		var n: int = runner.choice_options().size()
		if e.is_action_pressed("ui_down"):
			choice_focus = (choice_focus + 1) % n
		elif e.is_action_pressed("ui_up"):
			choice_focus = (choice_focus + n - 1) % n
		elif e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode < KEY_1 + n:
			_pick(e.keycode - KEY_1)
			return
		elif e.is_action_pressed("ui_accept"):
			_pick(choice_focus)
			return
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for i in choice_boxes.size():
				if choice_boxes[i].get_global_rect().has_point(e.position):
					_pick(i)
					return
		_refresh()
		return
	if e.is_action_pressed("ui_focus_next"):  # Tab
		runner.toggle_meaning()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if DialogText.TEXT_BOX.has_point(e.position):
			runner.tap_line()   # pressing the line opens its meaning first
		else:
			runner.advance()
		_refresh()
	elif e.is_action_pressed("ui_accept"):
		runner.advance()
		_refresh()


func _pick(i: int) -> void:
	if DialogueRunner.is_quest(runner.current()):
		leak_fixed = true   # the only quest on Day 1 (D1-312)
		lab.set_leak_fixed(true)
	runner.choose(i)
	choice_focus = 0
	_refresh()


func _refresh() -> void:
	var l := runner.current()
	if l.is_empty():
		return
	var tex := portrait_for(l.speaker, l.expression)
	portrait.visible = tex != ""
	if tex != "":
		portrait.texture = load(ART + "portraits/%s.png" % tex)
	_build_choices()
	if runner.is_text_input() and typewriter == null:
		_open_typewriter()


# --- name on the typewriter (M-5b): dimmed lab, paper in the typewriter, max 8 letters ---
const TW_POS := Vector2(400, 300)          # screen px (art 200,150 x2)
const TW_BASELINE := 344                   # art baseline y=22 on the paper
const TW_TEXT_X := 504                     # art x=52
const INK := Color8(40, 36, 40)
const NAME_OK_RECT := Rect2(520, 436, 240, 64)


func _open_typewriter() -> void:
	typewriter = CanvasLayer.new()
	typewriter.layer = 5
	add_child(typewriter)
	var dim := ColorRect.new()
	dim.color = Color8(10, 8, 12, 160)
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typewriter.add_child(dim)
	var tw := TextureRect.new()
	tw.texture = _x2(ART + "ui/ui_typewriter_input.png")
	tw.position = TW_POS
	tw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typewriter.add_child(tw)
	var f := Fonts.gothic()
	var prompt := Label.new()
	prompt.text = "なまえ:"
	prompt.add_theme_font_override("font", f)
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", INK)
	prompt.position = Vector2(TW_TEXT_X, TW_BASELINE - f.get_ascent(16))
	typewriter.add_child(prompt)
	name_edit = LineEdit.new()
	name_edit.max_length = 8
	name_edit.position = Vector2(TW_TEXT_X + 64, TW_BASELINE - f.get_ascent(24) - 4)
	name_edit.size = Vector2(212, f.get_height(24) + 8)
	name_edit.add_theme_font_override("font", f)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.add_theme_color_override("font_color", INK)
	name_edit.add_theme_color_override("caret_color", INK)
	name_edit.add_theme_constant_override("caret_width", 3)
	for st in ["normal", "focus", "read_only"]:
		name_edit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	name_edit.text_submitted.connect(func(t: String): _submit_name())
	typewriter.add_child(name_edit)
	var ok := NinePatchRect.new()
	ok.texture = _x2(ART + "ui/ui_keycap_choice_idle.png")
	for side in ["left", "right", "top", "bottom"]:
		ok.set("patch_margin_" + side, 16)
	ok.position = NAME_OK_RECT.position
	ok.size = NAME_OK_RECT.size
	ok.mouse_filter = Control.MOUSE_FILTER_STOP
	ok.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_submit_name())
	var label := Label.new()
	label.text = "이 이름으로"
	label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color8(60, 46, 36))
	label.size = NAME_OK_RECT.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ok.add_child(label)
	typewriter.add_child(ok)
	name_edit.grab_focus.call_deferred()


func _submit_name() -> void:
	if typewriter == null:
		return
	var t := name_edit.text
	typewriter.queue_free()
	typewriter = null
	runner.submit_name(t)
	_refresh()


static func portrait_for(speaker: String, expression: String) -> String:
	if speaker == "선택":  # the player is the one choosing
		speaker = "주인공"
	if not PORTRAITS.has(speaker):
		return ""
	var m: Dictionary = PORTRAITS[speaker]
	return m.get(expression, m["기본"])


func _build_choices() -> void:
	for b in choice_boxes:
		b.queue_free()
	choice_boxes.clear()
	if not runner.is_choice():
		return
	var opts: Array = runner.choice_options()
	for i in opts.size():
		var box := NinePatchRect.new()
		box.texture = _x2(ART + "ui/ui_keycap_choice_%s.png" % ("select" if i == choice_focus else "idle"))
		box.patch_margin_left = 16
		box.patch_margin_right = 16
		box.patch_margin_top = 16
		box.patch_margin_bottom = 16
		box.position = Vector2(CHOICE_X, CHOICE_Y + i * CHOICE_GAP)
		box.size = CHOICE_SIZE
		var label := Label.new()
		label.text = "%d  %s" % [i + 1, opts[i]]
		label.add_theme_font_override("font", Fonts.gothic())
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color8(60, 46, 36))
		label.position = Vector2(26, 16)
		box.add_child(label)
		ui.add_child(box)
		choice_boxes.append(box)


static func _x2(path: String) -> Texture2D:
	var img: Image = (load(path) as Texture2D).get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _sprite(path: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + path)
	s.centered = false
	s.position = pos
	add_child(s)
	return s
