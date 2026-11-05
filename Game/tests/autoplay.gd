extends Node
## Plays Day 1 through the real screens with fake key presses (no window needed):
##   godot --headless --path Game -- --autoplay [--from=T-7]
## main.gd adds this node. Prints each screen change and exits 0 when it reaches LEAVE.

var main: Node
var frames := 0
var log_screens: Array = []
var last := -1
var cooldown := 0


func _ready() -> void:
	main = get_parent()


func _process(_delta: float) -> void:
	_step()


func quit(code: int) -> void:
	get_tree().quit(code)


func _step() -> bool:
	frames += 1
	var flow: GameFlow = main.flow
	var want := str(main.args.get("shot-line", ""))
	if flow.current != last:
		last = flow.current
		var d: DayDirector = main.director
		log_screens.append("%s %s" % [GameFlow.Screen.keys()[last], d.scene_key()])
		print("frame %d → %s scene=%s card=%d" % [frames, GameFlow.Screen.keys()[last], d.scene_key(), d.card_n])
	if flow.current == GameFlow.Screen.LEAVE and want != "LEAVE":
		print("reached LEAVE after %d frames, %d screen changes" % [frames, log_screens.size()])
		quit(0)
		return true
	if frames > 40000:
		printerr("timeout on ", GameFlow.Screen.keys()[flow.current])
		quit(1)
		return true
	# --quit-line=D1-216: hard quit there (no save on exit) to test resuming from the last save point
	var stop := str(main.args.get("quit-line", ""))
	if stop != "" and (main.screen is DialogScreen or main.screen is IntroScreen) and main.screen.runner.current().get("id", "") == stop:
		print("quit at ", stop)
		quit(0)
		return true
	# --shot-line=D1-803: screenshot when that line is fully typed, then quit
	if want != "" and (main.screen is DialogScreen or main.screen is IntroScreen) and main.screen.runner.current().get("id", "") == want:
		main.screen.runner.revealed = main.screen.runner.total_chars()
		if main.screen is DialogScreen and main.args.has("peek"):
			main.screen._set_peek(int(main.args.peek))
		if main.screen is DialogScreen and main.args.has("history"):
			main.screen.open_history()
		set_process(false)
		main._take_shot(str(main.args.get("shot", "shot.png")), 5)
		return true
	if want != "" and main.screen is ReaderScreen and main.screen.tutorial and main.screen.tutorial.is_talking() \
			and main.screen.tutorial.runner.current().get("id", "") == want:
		main.screen.tutorial.runner.revealed = main.screen.tutorial.runner.total_chars()
		set_process(false)
		main._take_shot(str(main.args.get("shot", "shot.png")), 5)
		return true
	if want == "LEAVE" and main.screen is DayEndScreen and main.screen.title_alpha() >= 1.0:
		set_process(false)
		main._take_shot(str(main.args.get("shot", "shot.png")), 5)
		return true
	if want == "LAB" and main.screen is LabScreen:
		set_process(false)
		main._take_shot(str(main.args.get("shot", "shot.png")), 5)
		return true
	cooldown -= 1
	if cooldown > 0:
		return false
	cooldown = 2
	var s = main.screen
	if s is DialogScreen:
		if s.runner.is_time_input():
			s.runner.submit_time(510)
			s._refresh()
		elif s.typewriter:
			s.name_edit.text = "하루"
			s._submit_name()
		elif s.runner.is_choice():
			_key(KEY_1)
		else:
			_action("ui_accept")
	elif s is IntroScreen:
		if s.runner.is_choice():
			_key(KEY_1)
		else:
			_action("ui_accept")
	elif s is ReaderScreen:
		var m: ReaderModel = s.model
		if m.paused:
			m.focus_gained()   # a background window loses focus (C-3); the autoplayer has none
		if s.tutorial and s.tutorial.is_talking():
			_action("ui_accept")
		elif m.can_read() and m.t > 1.0:
			_action("ui_accept")
		elif m.can_grade():
			_key(KEY_3)
	elif s is LabScreen:
		_action("ui_accept")
	return false


func _action(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = a
	up.pressed = false
	Input.parse_input_event(up)


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
