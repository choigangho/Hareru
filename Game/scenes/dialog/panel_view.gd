class_name PanelView
extends Control
## Device panels opened from the lab while the dialog goes on in a subtitle band at the bottom
## (owner 2026-11-04): the logbook (mock M-6, T-4), the switchboard (M-7a, T-5) and the neural
## sync warning over the lab (M-7b, D1-528~535). Screen pixels; panel art 480x300 shown x2.

const UI := "res://art/ui/"
const PANEL_POS := Vector2(160, 60)
const BAND := Rect2(0, 650, 1280, 70)
const INK := Color8(70, 60, 50)
const RED_TINT := Color8(120, 10, 10, 70)
const WARN_POS := Vector2(340, 200)
const WARN_LINES := ["D1-528", "D1-529", "D1-530", "D1-531", "D1-532", "D1-533", "D1-534", "D1-535"]
const AD_TEXT := "광고 예시: 「꿈에서 먹는 스테이크 맛 캡슐」 「잠든 사이 외우는 언어 패치 (※ 효과 없음)」"   # D1-533
# logbook grid (rec_logbook.txt): origin (64,104), cell 34x26, 7 x 5; art px -> screen x2 + PANEL_POS
const GRID := Vector2(64, 104)
const CELL := Vector2(34, 26)
const NOISE_CELL := Vector2i(5, 4)
# switchboard (set_panel.txt)
const LABELS := {"목소리": [40, 30], "출근 알림": [160, 30], "집중 모드": [320, 30], "글자 크기": [40, 140],
	"움직임 줄이기": [160, 140], "볼륨": [320, 140], "뉴럴링크 백그라운드 동기화": [56, 226]}
const TIME_BUTTONS := [Rect2(482, 216, 64, 56), Rect2(554, 216, 64, 56), Rect2(626, 216, 64, 56)]  # −30 · +30 · 확정 (§9 ≥ 64)
const TIME_KEYS := [Rect2(860, 653, 190, 64), Rect2(1066, 653, 190, 64)]   # "이 시각으로" · "나중에"

var runner: DialogueRunner
var kind := ""                 # "logbook" | "settings" | ""
var today := {}                # Time.get_date_dict_from_system()
var dots: Array = []           # stability levels 0-4 of today's graduated words (up to 5)
var work_time := 510           # minutes after midnight (08:30)
var line_t := 0.0              # seconds the current line has been up
var warn_t := 0.0              # seconds the warning has been up (ad strip keeps scrolling across lines)
var _line_id := ""
var tex := {}

signal time_chosen(minutes: int)   # -1 = later


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in ["rec_logbook", "rec_stamp_today", "rec_noise_cell", "set_panel_open", "set_voice_knob_0",
			"set_focus_lever_off", "set_toggle_off", "set_slider_knob", "set_neural_cover_closed",
			"set_neural_cover_open", "ui_warning_neural", "ui_keycap_choice_idle"]:
		tex[n] = load(UI + n + ".png")
	for i in 5:
		tex["rec_dot_%d" % i] = load(UI + "rec_dot_%d.png" % i)
	if today.is_empty():
		today = Time.get_date_dict_from_system()


func _process(delta: float) -> void:
	var id: String = runner.current().get("id", "") if runner else ""
	if id != _line_id:
		_line_id = id
		line_t = 0.0
	line_t += delta
	warn_t = warn_t + delta if is_warning() else 0.0
	queue_redraw()


func is_warning() -> bool:
	return kind == "settings" and _line_id in WARN_LINES


func _art(tex_name: String, art_pos: Vector2) -> void:
	var t: Texture2D = tex[tex_name]
	draw_texture_rect(t, Rect2(PANEL_POS + art_pos * 2, t.get_size() * 2), false)


func cell_rect(col: int, row: int) -> Rect2:
	return Rect2(PANEL_POS + (GRID + Vector2(col, row) * CELL) * 2, CELL * 2)


## Calendar cell of a day this month (Sunday first). Vector2i(-1,-1) when it does not fit.
func day_cell(day: int) -> Vector2i:
	var first := Time.get_unix_time_from_datetime_dict({"year": today.year, "month": today.month, "day": 1})
	var offset: int = Time.get_datetime_dict_from_unix_time(first).weekday
	var i := offset + day - 1
	return Vector2i(i % 7, i / 7) if i < 35 else Vector2i(-1, -1)


func _draw() -> void:
	if kind == "":
		return
	var f := Fonts.gothic()
	if is_warning():
		_draw_warning(f)
	elif kind == "logbook":
		_draw_logbook()
	elif kind == "settings":
		_draw_settings(f)
	_draw_band(f)


func _draw_logbook() -> void:
	_art("rec_logbook", Vector2.ZERO)
	var m := Fonts.mincho()
	draw_string(m, Vector2(288, 180 + m.get_ascent(30)), "出勤簿 · %d月" % today.month, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	var c := day_cell(today.day)
	if c.x >= 0:
		var r := cell_rect(c.x, c.y)
		draw_texture_rect(tex.rec_stamp_today, Rect2(r.position + Vector2(12, 4), Vector2(44, 44)), false)
	var n := cell_rect(NOISE_CELL.x, NOISE_CELL.y)
	draw_texture_rect(tex.rec_noise_cell, Rect2(n.position + Vector2(2, 2), Vector2(66, 50)), false)
	for i in 5:
		var lvl: int = dots[i] if i < dots.size() else 0
		draw_texture_rect(tex["rec_dot_%d" % lvl], Rect2(Vector2(832, 284 + i * 48), Vector2(26, 26)), false)


func _draw_settings(f: Font) -> void:
	_art("set_panel_open", Vector2.ZERO)
	for label in LABELS:
		var p: Array = LABELS[label]
		draw_string(f, PANEL_POS + Vector2((p[0] + 4) * 2, p[1] * 2 + 1 + f.get_ascent(16)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DialogText.CREAM)
	_art("set_voice_knob_0", Vector2(58, 56))
	_art("set_focus_lever_off", Vector2(360, 54))
	_art("set_toggle_off", Vector2(208, 162))
	_art("set_slider_knob", Vector2(83, 161))
	_art("set_slider_knob", Vector2(390, 162))
	_art("set_toggle_off", Vector2(357, 238))
	# D1-524: the grey switch blinks under its cover; D1-527 the finger lifts the cover
	var n := int(_line_id.get_slice("-", 1)) if _line_id.begins_with("D1-") else 0
	var open := n >= 527 and n < 536
	if not open and n >= 524 and n < 527 and int(line_t * 3.0) % 2 == 1:
		pass   # blink: cover hidden every other third of a second
	else:
		_art("set_neural_cover_open" if open else "set_neural_cover_closed", Vector2(330, 224))
	var hh := work_time / 60
	var mm := work_time % 60
	var g := Fonts.gothic()
	draw_string(g, Vector2(496, 172 + g.get_ascent(30)), "%02d:%02d" % [hh, mm], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, DialogText.PH)


func _draw_warning(f: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), RED_TINT)
	var t: Texture2D = tex.ui_warning_neural
	draw_texture_rect(t, Rect2(WARN_POS, t.get_size() * 2), false)
	var cream := Color8(240, 220, 200)
	draw_string(f, WARN_POS + Vector2(10, 10 + f.get_ascent(16)), "NEURALLINK SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cream)
	draw_string(f, WARN_POS + Vector2(82, 54 + f.get_ascent(24)), "동기화 시 광고 수신에 동의한 것으로", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cream)
	draw_string(f, WARN_POS + Vector2(82, 88 + f.get_ascent(24)), "간주합니다 (1日 400件)", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cream)
	# ad strip (5,92)-(294,114): scrolls right -> left, clipped by drawing only what is inside
	var strip := Rect2(WARN_POS + Vector2(12, 186), Vector2(574, 40))
	var w := f.get_string_size(AD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := strip.end.x - fmod(warn_t * 60.0 + strip.size.x * 0.95, w + strip.size.x)   # starts already on screen
	var cx := x
	for ch in AD_TEXT:
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		if cx >= strip.position.x and cx + cw <= strip.end.x:
			draw_string(f, Vector2(cx, strip.position.y + 26), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(200, 120, 110))
		cx += cw


func _draw_band(f: Font) -> void:
	var l := runner.current()
	if l.is_empty() or runner.hold:
		return
	draw_rect(BAND, Color8(10, 8, 12, 210))
	var who := runner.speaker_name()
	var x := 40.0
	if who != "":
		draw_string(f, Vector2(x, 694), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DialogText.AMBER)
		x = 180.0
	var text := Ruby.plain_text(runner.main_text()).left(int(runner.revealed))
	if runner.meaning_open and runner.meaning() != "":
		text = runner.meaning()
	if _glitched(l):
		text = "■■■■ ■■■■■ ■■■■"
	var col := DialogText.CREAM if who == "" or l.speaker == "독백" else DialogText.PH
	var width := 660.0 if runner.is_time_input() else 1060.0
	draw_string(f, Vector2(x, 696), text, HORIZONTAL_ALIGNMENT_LEFT, width, 24, col)
	if runner.is_time_input():
		var labels := ["이 시각으로", "나중에"]
		for i in 2:
			var r: Rect2 = TIME_KEYS[i]
			draw_texture_rect(tex.ui_keycap_choice_idle, r, false)
			draw_string(f, r.position + Vector2(0, 40), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color8(60, 46, 36))


## D1-411: the corrupted record reads for 0.8 s, then turns to noise (note "0.8초 표시 후 노이즈").
func _glitched(l: Dictionary) -> bool:
	return str(l.get("note", "")).contains("0.8초 표시 후 노이즈") and line_t > 0.8


## Clicks inside the panel. Returns true when used (the dialog does not advance on it).
func press(pos: Vector2) -> bool:
	if kind == "":
		return false
	if runner.is_time_input():
		for i in 3:
			if (TIME_BUTTONS[i] as Rect2).has_point(pos):
				if i == 2:
					time_chosen.emit(work_time)
				else:
					work_time = posmod(work_time + (30 if i == 1 else -30), 24 * 60)
				return true
		for i in 2:
			if (TIME_KEYS[i] as Rect2).has_point(pos):
				time_chosen.emit(work_time if i == 0 else -1)
				return true
		return true
	if kind == "logbook" and cell_rect(NOISE_CELL.x, NOISE_CELL.y).has_point(pos):
		if _line_id in ["D1-410", "D1-411"]:
			runner.revealed = runner.total_chars()
			runner.next()
		return true
	return false
