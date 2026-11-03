class_name DialogScreen
extends Node2D
## Dialog over the lab (mock M-2): dock + portrait CRT in art pixels, text on a screen layer.
## Keys: Enter/Space/click = next (finishes typing first), Tab = Korean meaning,
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


func setup(scene_lines: Array, key := "") -> void:
	scene_key = key
	runner.load_scene(scene_lines)


func _ready() -> void:
	lab = LabScreen.new()
	add_child(lab)
	lab.layers.hint.visible = false  # the "next task" dot belongs to free lab time, not dialog
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
	_refresh()


func _process(delta: float) -> void:
	if not runner.is_done():
		runner.tick(delta)


func _unhandled_input(e: InputEvent) -> void:
	if runner.is_done():
		return
	if runner.is_choice():
		var n: int = runner.current().options.size()
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
	elif e.is_action_pressed("ui_accept") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		runner.advance()
		_refresh()


func _pick(i: int) -> void:
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
	var opts: Array = runner.current().options
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
