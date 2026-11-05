class_name IntroScreen
extends Node2D
## T-0 intro (mock M-4): typed narration on the old CRT (D1-001~003), full-screen cuts (city,
## code signs, NeuroLex logo, alley building) and the voice keycaps. Same runner API as
## DialogScreen so the day director drives it the same way. Art 640x360 in the x2 world.
## Keys: Enter/click = next (finishes typing first), Esc = skip the intro (to the voice choice).

const ART := "res://art/intro/"
const GLASS := Rect2(112, 52, 1056, 548)        # CRT glass on screen
const CRT_TEXT := Vector2(150, 170)             # mock ①: first baseline
const CRT_LINE_H := 40
const SUB_BASELINE := 664                       # subtitle line over picture cuts
const SIZE := 24
const VOICE_Y := 632
const VOICE_X := [820, 930, 1040]               # mock ④ keycaps A/B/C
const VOICE_SIZE := Vector2(96, 64)             # keycap 48x32 x2, §9 ≥ 64
const VOICE_LOCKED := [false, true, true]       # owner 2026-11-03: B · C on hold, shown locked
const SKIP_TO := "D1-023"                       # Esc: straight to the alley

## Which picture each line sits on (by line number): crt, city, sign, logo, building.
## Owner 2026-11-04 (D-14): the CRT only for D1-001~003 (city showing through in green);
## the later narration that was on the CRT sits on the picture before it (logo, sign).
static func backdrop_for(line_id: String) -> String:
	var n := int(line_id.get_slice("-", 1))
	if n <= 3:
		return "crt"
	if n <= 6:
		return "city"
	if n >= 10 and n <= 13:
		return "logo"
	if n <= 22:
		return "sign"
	return "building"


var runner := DialogueRunner.new()
var lab: LabScreen = null      # API parity with DialogScreen (no lab in the intro)
var scene_key := ""
var paragraph: Array = []      # CRT lines typed so far in this paragraph
var backdrop := ""
var pics := {}
var text: Control
var voice_focus := 0
var key_tex: Texture2D
var key_sel_tex: Texture2D
var sign_mosaic: ColorRect
const SIGN_RECT := Rect2(540, 312, 204, 60)      # building sign (art 135,78–186,93 x4), mosaic by code
var _lines: Array = []
var _start_after := ""


func setup(scene_lines: Array, key := "", start_after := "") -> void:
	scene_key = key
	_lines = scene_lines
	_start_after = start_after


func set_closeup(_n: String) -> void:
	pass


func _ready() -> void:
	pics.city = _pic("intro_city_v2.png", 1)
	pics.sign = _pic("intro_sign_closeup_v4.png", 2)
	pics.building = _pic("intro_building_v1.png", 2)
	pics.crt_on = _pic("intro_crt_screen_on.png", 1)
	pics.crt_city = _pic("intro_city_v2.png", 1)    # under the frame: only the glass shows it
	var ph := ShaderMaterial.new()
	ph.shader = preload("res://shaders/phosphor.gdshader")
	pics.crt_city.material = ph
	pics.logo = _pic("intro_neurolex_logo.png", 2)   # full-screen cut like the others (owner 2026-11-04)
	pics.frame = _pic("intro_crt_frame.png", 1)
	key_tex = DialogScreen._x2("res://art/ui/ui_keycap_choice_idle.png")
	key_sel_tex = DialogScreen._x2("res://art/ui/ui_keycap_choice_select.png")
	var mlayer := CanvasLayer.new()
	add_child(mlayer)
	sign_mosaic = ColorRect.new()
	sign_mosaic.position = SIGN_RECT.position
	sign_mosaic.size = SIGN_RECT.size
	sign_mosaic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/pixelate.gdshader")
	sign_mosaic.material = mat
	mlayer.add_child(sign_mosaic)
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	text = Control.new()
	text.size = Vector2(1280, 720)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.draw.connect(_draw_text)
	ui.add_child(text)
	runner.finished.connect(func(): EventBus.dialog_finished.emit(scene_key))
	runner.load_scene(_lines, _start_after)
	_refresh()


func _pic(file: String, s: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(ART + file)
	sp.centered = false
	sp.scale = Vector2(s, s)
	sp.visible = false
	add_child(sp)
	return sp


func _process(delta: float) -> void:
	if not runner.is_done():
		runner.tick(delta)
	text.queue_redraw()


func _refresh() -> void:
	var l := runner.current()
	if l.is_empty():
		return
	var b := backdrop_for(l.id)
	if b != backdrop:
		paragraph.clear()
	backdrop = b
	for k in pics:
		pics[k].visible = false
	match b:
		"crt":
			pics.crt_on.visible = true
			pics.crt_city.visible = true
			pics.frame.visible = true
		_:
			pics[b].visible = true
	sign_mosaic.visible = b == "building"


## The previous line ended a paragraph (note "문단 쉼"): the CRT clears before the next one.
func _advance() -> void:
	var was := runner.current()
	if backdrop == "crt" and not was.is_empty():
		paragraph.append(runner.main_text())
		if str(was.get("note", "")).contains("문단 쉼"):
			paragraph.clear()
	runner.advance()
	if runner.current().get("id", "") != was.get("id", ""):
		_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if runner.is_done():
		return
	if e.is_action_pressed("ui_cancel") and int(runner.current().get("id", "D1-0").get_slice("-", 1)) < 23:
		paragraph.clear()
		runner.jump_to(SKIP_TO)
		runner.next()
		_refresh()
		return
	if runner.is_choice():
		_choice_input(e)
		return
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if click or e.is_action_pressed("ui_accept"):
		if runner.is_typing():
			runner.revealed = runner.total_chars()
		else:
			_advance()


func _choice_input(e: InputEvent) -> void:
	var pick := -1
	if e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_3:
		pick = e.keycode - KEY_1
	elif e.is_action_pressed("ui_accept"):
		pick = voice_focus
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in 3:
			if voice_rect(i).has_point(e.position):
				pick = i
	if pick >= 0 and not VOICE_LOCKED[pick]:
		runner.choose(pick)
		_refresh()


static func voice_rect(i: int) -> Rect2:
	return Rect2(Vector2(VOICE_X[i], VOICE_Y), VOICE_SIZE)


func _draw_text() -> void:
	var l := runner.current()
	if l.is_empty() or runner.hold:
		return
	var f := Fonts.gothic()
	var now := Ruby.plain_text(runner.main_text()).left(int(runner.revealed))
	if backdrop == "crt":
		var y := CRT_TEXT.y
		# dark band behind the typed lines so they read over the city
		var rows := paragraph.size() + (0 if runner.is_choice() else 1)
		text.draw_rect(Rect2(GLASS.position.x, CRT_TEXT.y - 52, 890, 52 + rows * CRT_LINE_H - 6), Color8(6, 16, 10, 200))
		for p in paragraph:
			text.draw_string(f, Vector2(CRT_TEXT.x, y), Ruby.plain_text(p), HORIZONTAL_ALIGNMENT_LEFT, GLASS.size.x - 80, SIZE, DialogText.PH)
			y += CRT_LINE_H
		if not runner.is_choice():
			text.draw_string(f, Vector2(CRT_TEXT.x, y), now + ("_" if int(Time.get_ticks_msec() / 400) % 2 == 0 else ""), HORIZONTAL_ALIGNMENT_LEFT, GLASS.size.x - 80, SIZE, DialogText.PH)
		return
	# picture cuts: one subtitle line on a dark band at the bottom
	text.draw_rect(Rect2(0, 600, 1280, 120), Color8(10, 8, 12, 170))
	var col := DialogText.CREAM if l.speaker != "타자" else DialogText.PH
	if runner.is_choice():
		text.draw_string(f, Vector2(120, SUB_BASELINE), runner.main_text(), HORIZONTAL_ALIGNMENT_LEFT, 640, SIZE, col)
		_draw_voice_keys(f)
	else:
		text.draw_string(f, Vector2(120, SUB_BASELINE), now, HORIZONTAL_ALIGNMENT_LEFT, 1040, SIZE, col)


func _draw_voice_keys(f: Font) -> void:
	var tex := key_tex
	var sel := key_sel_tex
	for i in 3:
		var r := voice_rect(i)
		var mod := Color(1, 1, 1, 0.4) if VOICE_LOCKED[i] else Color.WHITE
		text.draw_texture_rect(sel if i == voice_focus else tex, r, false, mod)
		text.draw_string(f, r.position + Vector2(0, 36), "ABC"[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, SIZE, Color8(60, 46, 36, 255 if not VOICE_LOCKED[i] else 110))
	var tag := "이 목소리로"
	text.draw_string(f, Vector2(VOICE_X[0], VOICE_Y - 14), tag, HORIZONTAL_ALIGNMENT_CENTER, VOICE_SIZE.x, 16, DialogText.CREAM)
