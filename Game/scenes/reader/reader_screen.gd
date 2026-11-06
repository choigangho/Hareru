class_name ReaderScreen
extends Node2D
## Front reader (v13, owner 2026-11-04). Art is 320x180 shown x4 (this node scales x2 inside
## the x2 world); the paper, scan bar, plates, receipt, folders and monitor are drawn on top
## at screen resolution (ReaderPaper, ReaderDesk).
## Keys: Space/Enter or click the paper = read, 1-4 or click a lever = grade, Esc = stand up,
## wheel / two fingers / ↑↓ over the paper = scroll it.

const ART := "res://art/reader_front/"
const STAND_RECT := Rect2(24, 640, 176, 64)       # "일어서기" keycap on the printer base (§9: Esc also works)
const BAND := Rect2(0, 650, 1280, 70)             # subtitle band, same as the dialog's
const LOG_MAX := 12

var model := ReaderModel.new()
var bank: WordBank
var paper: ReaderPaper
var desk: ReaderDesk
var ui: CanvasLayer
var stand_button: NinePatchRect
var stand_blocked_flash := 0.0
var tutorial: TutorialTalk = null   # T-2: the chief talks over the reader (owner 2026-11-04)
var talk_layer: Control
var reading_log := []                     # reading log on the receipt, newest first
var _log_no := 0
var keep_focus := false             # screenshots: a window opening must not restart the card (C-3)


func setup(session: StudySession, word_bank: WordBank) -> void:
	bank = word_bank
	if tutorial:
		model.start_empty(session)   # the script puts documents 1-5 in (TutorialTalk)
	else:
		model.start(session)


func _ready() -> void:
	scale = Vector2(2, 2)
	var bg := Sprite2D.new()
	bg.texture = load(ART + "reader_bg.png")
	bg.centered = false
	add_child(bg)
	ui = CanvasLayer.new()
	add_child(ui)
	paper = ReaderPaper.new()
	paper.model = model
	paper.bank = bank
	ui.add_child(paper)
	desk = ReaderDesk.new()
	desk.model = model
	desk.bank = bank
	desk.screen = self
	ui.add_child(desk)
	_build_stand_button()
	if tutorial:
		stand_button.visible = false   # the script ends the tutorial (D1-257), not the player
		var tl := CanvasLayer.new()
		tl.layer = 4
		add_child(tl)
		talk_layer = Control.new()
		talk_layer.size = Vector2(1280, 720)
		talk_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		talk_layer.draw.connect(_draw_talk)
		tl.add_child(talk_layer)
		tutorial.finished.connect(func(): EventBus.dialog_finished.emit(DayDirector.TUTORIAL_SCENE))
	else:
		model.finished.connect(func(): EventBus.reading_finished.emit())
	_apply(0.0)


func _process(delta: float) -> void:
	model.clock = Time.get_unix_time_from_system()
	if tutorial:
		tutorial.update()
		if tutorial.is_talking():
			tutorial.runner.tick(delta)
		talk_layer.queue_redraw()
	model.tick(delta)
	stand_blocked_flash = maxf(0.0, stand_blocked_flash - delta)
	_apply(delta)


func _apply(delta: float) -> void:
	paper.step(delta)
	desk.queue_redraw()
	# while a read card waits for its key, the stand-up keycap is dimmed
	stand_button.modulate = Color(1, 1, 1, 0.45) if not model.can_stand_up() else Color.WHITE


func _unhandled_input(e: InputEvent) -> void:
	if _scroll_input(e):
		return
	if tutorial and tutorial.is_talking():
		var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
		if click or e.is_action_pressed("ui_accept"):
			tutorial.runner.tap_line()
			tutorial.update()
		return
	if tutorial and e.is_action_pressed("ui_cancel"):
		return   # no standing up in the middle of the tutorial
	_reader_input(e)
	if tutorial:
		tutorial.update()


## Wheel / trackpad two fingers over the paper, or ↑↓, move the paper (same step as Godot's
## ScrollContainer: an eighth of the view per notch). Returns true when the event was used.
func _scroll_input(e: InputEvent) -> bool:
	var step := PaperScroll.VIEW / 8.0
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not ReaderPaper.on_glass(e.position):
			return false
		var f: float = e.factor if e.factor > 0.0 else 1.0
		paper.scroll.move(step * f * (-1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
		return true
	if e is InputEventPanGesture:
		if not ReaderPaper.on_glass(e.position):
			return false
		paper.scroll.move(PaperScroll.VIEW * e.delta.y / 8.0)
		return true
	if e is InputEventKey and e.pressed and e.keycode in [KEY_UP, KEY_DOWN] and paper.scroll.can_scroll():
		paper.scroll.move(step * (-1.0 if e.keycode == KEY_UP else 1.0))
		return true
	return false


func _reader_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_try_stand_up()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_4:
		_grade(e.keycode - KEY_1 + 1)
	elif e.is_action_pressed("ui_accept"):
		model.read()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if STAND_RECT.has_point(e.position):
			_try_stand_up()
			return
		if ReaderPaper.on_glass(e.position):
			model.read()
		for i in 4:
			if (ReaderDesk.KEY_RECTS[i] as Rect2).has_point(e.position):
				_grade(i + 1)


func _grade(key: int) -> void:
	var id := model.word_id()
	var reaction := model.reaction
	if model.grade(key) == 0:
		return
	var w := bank.word(id)
	var now := Time.get_time_dict_from_system()
	_log_no += 1
	reading_log.push_front({"no": _log_no, "time": "%02d:%02d" % [now.hour, now.minute], "term": w.get("term", id),
		"reading": w.get("reading", ""), "reaction": reaction, "key": ReaderDesk.KEY_NAMES[key - 1]})
	if reading_log.size() > LOG_MAX:
		reading_log.resize(LOG_MAX)


func _try_stand_up() -> void:
	if model.stand_up():
		EventBus.stand_up.emit()
	else:
		stand_blocked_flash = 0.6   # keys must be pressed first


func _notification(what: int) -> void:
	if keep_focus:
		return
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


## Which face the monitor shows: only while the chief (주임) talks at the very start of the
## tutorial, before document 1 goes in (owner 2026-11-04: not on every line).
func chief_face() -> String:
	if tutorial == null or not tutorial.is_talking() or tutorial.director.card_n > 0:
		return ""
	var l := tutorial.runner.current()
	if l.get("speaker", "") != "주임":
		return ""
	var ex := str(l.get("expression", ""))
	if ex in ["미소", "뿌듯", "반짝"]:
		return "smile"
	if ex in ["당황", "난감"]:
		return "flustered"
	return "calm"


func _draw_talk() -> void:
	if not tutorial.is_talking():
		return
	var r := tutorial.runner
	var l := r.current()
	var f := Fonts.gothic()
	var text := Ruby.plain_text(r.main_text()).left(int(r.revealed))
	if r.meaning_open and r.meaning() != "":
		text = r.meaning()
	# subtitle band: the whole line
	talk_layer.draw_rect(BAND, Color8(10, 8, 12, 210))
	var who := r.speaker_name()
	var x := 40.0
	if who != "":
		talk_layer.draw_string(f, Vector2(x, 694), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DialogText.AMBER)
		x = 180.0
	var col := DialogText.CREAM if who == "" or l.get("speaker", "") == "독백" else DialogText.PH
	talk_layer.draw_string(f, Vector2(x, 696), text, HORIZONTAL_ALIGNMENT_LEFT, 1060.0, 24, col)
