class_name ReaderScreen
extends Node2D
## Top-down reader desk (mock M-3). Art is 320x180 shown x4 (this node scales x2 inside the x2 world).
## Keys: Space/Enter or click the handle = read, 1-4 or click a key = grade, Esc = stand up.

const ART := "res://art/reader/"
const STAMP_POS := Vector2(186, 90)
const HANDLE_RECT := Rect2(920, 140, 140, 500)   # screen px around the orange grip
const STAND_RECT := Rect2(24, 640, 176, 64)       # "일어서기" keycap on the desk (§9: Esc also works)

var model := ReaderModel.new()
var bank: WordBank
var parts := {}
var text: ReaderText
var ui: CanvasLayer
var top: Node2D
var stand_button: NinePatchRect
var stand_blocked_flash := 0.0


func setup(session: StudySession, word_bank: WordBank) -> void:
	bank = word_bank
	model.start(session)


func _ready() -> void:
	# Draw order: desk + paper (world) → paper text (layer 1) → example mosaic (layer 2)
	# → moving machine parts above the paper (layer 3): the head passes OVER the text.
	scale = Vector2(2, 2)
	_part("desk_reader_bg", Vector2.ZERO, self)
	_part("paper_on_mat", Vector2.ZERO, self)
	var top_layer := CanvasLayer.new()
	top_layer.layer = 3
	add_child(top_layer)
	top = Node2D.new()
	top.scale = Vector2(4, 4)
	top_layer.add_child(top)
	for n in ["head_park", "head_scan_1", "head_scan_2", "head_scan_3", "head_scan_4", "arm_up", "arm_half", "arm_down", "monitor_face_calm"]:
		_part(n, Vector2.ZERO, top)
	for i in range(1, 5):
		_part("key_%d_lit" % i, Vector2.ZERO, top)
		_part("key_%d_down" % i, Vector2.ZERO, top)
	_part("stamp_doku", STAMP_POS, top)
	_part("stamp_sai", STAMP_POS, top)
	parts.monitor_face_calm.visible = false  # chief's face only for guide lines / events (mock ③④)
	ui = CanvasLayer.new()
	add_child(ui)
	text = ReaderText.new()
	text.model = model
	text.bank = bank
	ui.add_child(text)
	_build_stand_button()
	var mlayer := CanvasLayer.new()
	mlayer.layer = 2
	add_child(mlayer)
	var mos := ColorRect.new()
	mos.position = Vector2(450, 360)
	mos.size = Vector2(436, 44)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/mosaic.gdshader")
	mat.set_shader_parameter("rect_size", mos.size)
	mos.material = mat
	mos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mlayer.add_child(mos)
	text.mosaic = mos
	model.finished.connect(func(): EventBus.reading_finished.emit())
	_apply()


func _process(delta: float) -> void:
	model.clock = Time.get_unix_time_from_system()
	model.tick(delta)
	stand_blocked_flash = maxf(0.0, stand_blocked_flash - delta)
	_apply()


func _apply() -> void:
	var P := ReaderModel.Phase
	var ph := model.phase
	parts.paper_on_mat.visible = ph != P.FINISHED
	parts.paper_on_mat.position.x = -40.0 * (1.0 - clampf(model.t / ReaderModel.INSERT_TIME, 0, 1)) if ph == P.INSERT else 0.0
	var hf := model.head_frame()
	parts.head_park.visible = hf == 0
	for i in range(1, 5):
		parts["head_scan_%d" % i].visible = hf == i
	var read_anim := ph == P.READ and model.t < 0.25
	parts.arm_up.visible = ph in [P.INSERT, P.SCAN, P.FINISHED]
	parts.arm_half.visible = read_anim
	parts.arm_down.visible = (ph == P.READ and not read_anim) or ph == P.STAMP
	for i in range(1, 5):
		parts["key_%d_lit" % i].visible = ph == P.READ
		parts["key_%d_down" % i].visible = ph == P.STAMP and model.last_key == i
	# while a read card waits for its key, the stand-up keycap is dimmed; a blocked press makes the lamps blink
	stand_button.modulate = Color(1, 1, 1, 0.45) if not model.can_stand_up() else Color.WHITE
	if stand_blocked_flash > 0.0 and int(stand_blocked_flash * 10) % 2 == 0:
		for i in range(1, 5):
			parts["key_%d_lit" % i].visible = false
	parts.stamp_doku.visible = ph == P.STAMP and model.stamped_graduated()
	parts.stamp_sai.visible = ph == P.STAMP and not model.stamped_graduated()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_try_stand_up()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_4:
		model.grade(e.keycode - KEY_1 + 1)
	elif e.is_action_pressed("ui_accept"):
		model.read()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if STAND_RECT.has_point(e.position):
			_try_stand_up()
			return
		if HANDLE_RECT.has_point(e.position):
			model.read()
		for i in 4:
			if (ReaderText.KEY_RECTS[i] as Rect2).has_point(e.position):
				model.grade(i + 1)


func _try_stand_up() -> void:
	if model.stand_up():
		EventBus.stand_up.emit()
	else:
		stand_blocked_flash = 0.6   # keys must be pressed first


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		model.focus_lost()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		model.focus_gained()


func _build_stand_button() -> void:
	var box := NinePatchRect.new()
	box.texture = DialogScreen._x2("res://art/ui/ui_keycap_choice_idle.png")
	for side in ["left", "right", "top", "bottom"]:
		box.set("patch_margin_" + side, 16)
	box.position = STAND_RECT.position
	box.size = STAND_RECT.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "일어서기"
	label.add_theme_font_override("font", Fonts.gothic())
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color8(60, 46, 36))
	label.position = Vector2(46, 16)
	box.add_child(label)
	ui.add_child(box)
	stand_button = box


func _part(n: String, pos: Vector2, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = load(ART + n + ".png")
	s.centered = false
	s.position = pos
	parent.add_child(s)
	parts[n] = s
	return s
