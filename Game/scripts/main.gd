extends Node
## Root: owns the GameFlow, swaps the screen node on each state change.
## Normal run: the DayDirector plays Day 1 from T-0 (--from=T-7 starts at another scene).
## Single-screen preview args (after `--`): --screen=lab|dialog|reader|leave --light=before|after|night
##   --day --shot=path.png [--wait=frames]
##   dialog: --scene=T-1 (D1 scene key) [--line=D1-108] [--typed] [--meaning]
##   reader: --pile=tutorial|task [--at=seconds into scan] [--read] [--grade=1-4]
##           [--word=id] [--met=id,id (learned)] [--seen=id,id (passed)] [--scroll=px]

const ART_SCALE := 2
const STORY := "res://data/story_n5.json"

var flow := GameFlow.new()
var bank: WordBank
var session := StudySession.new()
var director: DayDirector   # null in single-screen preview (--screen=…)
var save_path := ""         # "" = not saving (previews, autoplay without --save)
var world: Node2D
var screen: Node2D
var args := {}


func _ready() -> void:
	add_child(Sound.new())
	world = Node2D.new()
	world.name = "World"
	world.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(world)
	flow.changed.connect(_on_flow_changed)
	EventBus.dialog_finished.connect(_on_dialog_finished)
	EventBus.reading_finished.connect(_on_reading_finished)
	EventBus.stand_up.connect(_on_stand_up)
	EventBus.desk_pressed.connect(_on_desk_pressed)
	args = parse_args(OS.get_cmdline_user_args())
	bank = WordBank.load_default()
	session.tz_bias_min = Time.get_time_zone_from_system().bias
	if not args.has("screen"):
		director = DayDirector.new(bank.d1_queue.tutorial, bank.d1_queue.task)
		session.start(director.tutorial)
		if args.has("save") or not (args.has("autoplay") or args.has("from")):
			save_path = str(args.get("save", SaveGame.PATH))
		if args.has("from"):
			director.start_at(str(args.from))
		elif save_path != "" and not args.has("new"):
			_load()
		session.graduated.connect(func(_id, _st): _save())
		flow.current = director.screen() as GameFlow.Screen
	_show(flow.current)
	_apply_args()
	if args.has("autoplay"):
		add_child(load("res://tests/autoplay.gd").new())


# --- Day 1 director wiring: every event updates the director, then the screen follows it ---

func _on_dialog_finished(_key: String) -> void:
	if director == null:
		flow.go_to(GameFlow.Screen.LAB)
		return
	director.on_scene_done()
	_sync.call_deferred()


func _on_reading_finished() -> void:
	if director == null:
		flow.go_to(GameFlow.Screen.LAB)
		return
	if director.phase == DayDirector.Phase.CARD:
		director.on_card_done((screen as ReaderScreen).model.last_key)
	else:
		director.on_task_done()
	_sync.call_deferred()


func _on_stand_up() -> void:
	if director == null:
		flow.go_to(GameFlow.Screen.LAB)
		return
	var rs := screen as ReaderScreen
	if director.phase == DayDirector.Phase.CARD and rs and rs.model.last_key > 0:
		director.on_card_done(rs.model.last_key)   # stood up during the stamp: the card is done
	else:
		director.on_stand_up()
	_sync.call_deferred()


func _on_desk_pressed() -> void:
	if director != null and director.on_desk_pressed():
		_sync.call_deferred()
	elif director == null:
		flow.go_to(GameFlow.Screen.READER)


func _now() -> float:
	return Time.get_unix_time_from_system()


func _save() -> void:
	if save_path != "" and director:
		SaveGame.write(SaveGame.capture(director, session, _now(), session.tz_bias_min), save_path)


func _load() -> void:
	var d := SaveGame.read(save_path)
	if not d.is_empty() and not SaveGame.restore(d, director, session, _now(), session.tz_bias_min):
		push_warning("save file not usable, starting Day 1 fresh: " + save_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


## Shows what the director wants. Same screen (next scene, next card) = rebuild in place.
## Every director step is also a save point (quitting resumes at that scene or card).
func _sync() -> void:
	_save()
	var target := director.screen() as GameFlow.Screen
	if target == flow.current:
		_show(target)
	elif not flow.go_to(target):
		push_error("flow refused %s -> %s" % [flow.current, target])


static func parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for a in raw:
		if not a.begins_with("--"):
			continue
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out


func _on_flow_changed(from_screen: int, to_screen: int) -> void:
	_show(to_screen)
	EventBus.screen_changed.emit(from_screen, to_screen)


func _show(s: int) -> void:
	if screen:
		screen.queue_free()
	if s == GameFlow.Screen.LAB:
		screen = LabScreen.new()
		if director:
			screen.light_state = director.light as LabScreen.LightState
			screen.leak_fixed = director.leak_fixed
			screen.bucket_full = director.bucket_full
			screen.target = director.target
	elif s == GameFlow.Screen.DIALOG:
		screen = _dialog_screen()
	elif s == GameFlow.Screen.READER:
		screen = ReaderScreen.new()
		if director and director.phase == DayDirector.Phase.TUTORIAL:
			_tutorial_reader(screen)
		else:
			if director:
				_fill_reader(screen)
			else:
				var pile := str(args.get("pile", "tutorial"))
				session.start(bank.d1_queue.get(pile, bank.d1_queue.tutorial))
			screen.setup(session, bank)
	elif s == GameFlow.Screen.LEAVE:
		screen = DayEndScreen.new()
	else:
		screen = preload("res://scenes/placeholder/placeholder_screen.gd").new()
		screen.title = GameFlow.Screen.keys()[s]
	screen.name = "Screen"
	world.add_child(screen)
	_sound_place(s)


## Loops for the place on screen: the street (intro), the lab, the reader, the night (leave).
func _sound_place(s: int) -> void:
	var leak := director != null and not director.leak_fixed
	if s == GameFlow.Screen.READER:
		Sound.go("reader", leak)
	elif s == GameFlow.Screen.LEAVE:
		Sound.go("night")
	elif screen is IntroScreen:
		Sound.go("outside")
	else:
		Sound.go("lab", leak)


func _dialog_screen() -> Node2D:
	var key := str(args.get("scene", "T-1")) if director == null else director.scene_key()
	var ds: Node2D = IntroScreen.new() if key == "T-0" else DialogScreen.new()
	if director == null:
		ds.setup(DialogueRunner.scene_from_file(STORY, "D1", key), key)
		return ds
	if ds is DialogScreen:
		ds.light = director.light
		ds.leak_fixed = director.leak_fixed
		ds.closeup = director.closeup
		ds.bucket_full = director.bucket_full
		ds.panel = director.panel
		ds.dots = _stability_dots()
	ds.setup(DialogueRunner.scene_from_file(STORY, "D1", key), key, director.resume_after)
	ds.runner.skip_ids = director.skip_ids
	ds.runner.vars["이름"] = director.player_name
	ds.runner.shown.connect(director.on_line_shown)
	if ds is DialogScreen:
		ds.history = director.history
	if director.work_time >= 0:
		ds.runner.vars["출근"] = "%02d:%02d" % [director.work_time / 60, director.work_time % 60]
	ds.runner.time_given.connect(func(m: int):
		director.on_work_time(m)
		_save())
	ds.runner.quest_done.connect(director.on_quest)
	ds.runner.quest_done.connect(func(l: Dictionary): Sound.on_direction(l))
	ds.runner.shown.connect(Sound.on_line)
	ds.runner.direction.connect(Sound.on_direction)
	ds.runner.name_given.connect(func(n: String):
		director.on_name(n)
		_save())
	ds.runner.cue.connect(func(l: Dictionary):
		if director.on_cue(l):
			ds.runner.hold = true
			_sync.call_deferred())
	ds.runner.direction.connect(func(l: Dictionary):
		if director.on_direction(l) and ds.lab:
			ds.lab.bucket_full = director.bucket_full
			ds.lab.set_light(director.light)
			ds.set_closeup(director.closeup)
			if ds is DialogScreen and ds.panel != director.panel:
				ds.set_panel(director.panel))
	return ds


## Logbook dots (M-6): one per tutorial word, 0 = not learned yet, 1-4 by FSRS stability (days).
func _stability_dots() -> Array:
	var out := []
	for w in director.tutorial:
		var st: float = float(session.records.get(w, {}).get("stability", 0.0))
		out.append(0 if st <= 0.0 else (1 if st < 1.0 else (2 if st < 3.0 else (3 if st < 7.0 else 4))))
	return out


## T-2 on the reader: the chief's lines run over the reader and put documents 1-5 in.
func _tutorial_reader(rs: ReaderScreen) -> void:
	var talk := TutorialTalk.new()
	talk.model = rs.model
	talk.director = director
	talk.runner.vars["이름"] = director.player_name
	talk.runner.shown.connect(director.on_line_shown)
	talk.runner.shown.connect(func(_e): _save())
	talk.runner.shown.connect(Sound.on_line)
	talk.runner.direction.connect(Sound.on_direction)
	rs.tutorial = talk
	rs.setup(session, bank)
	talk.start(DialogueRunner.scene_from_file(STORY, "D1", DayDirector.TUTORIAL_SCENE), director.resume_after)


## Tutorial: the card the script names goes on top and the reader stops after it.
## Task: whatever is left of the tutorial pile, then the 15 documents.
func _fill_reader(rs: ReaderScreen) -> void:
	if director.phase == DayDirector.Phase.CARD:
		var w := director.card_word()
		session.queue.erase(w)
		session.queue.push_front(w)
		rs.model.card_limit = 1
	elif not director.task_started:
		session.start(director.begin_task(session.queue))


func _apply_args() -> void:
	if args.has("screen"):
		var s := GameFlow.screen_from_name(str(args.screen))
		if s >= 0 and s != flow.current:
			flow.go_to(s)
	if screen is DialogScreen:
		if args.has("line"):
			screen.runner.jump_to(str(args.line))
			screen._refresh()
		if args.has("typed"):
			screen.runner.revealed = screen.runner.total_chars()
		if args.has("meaning"):
			screen.runner.meaning_open = true
	if screen is ReaderScreen:
		var m: ReaderModel = screen.model
		screen.keep_focus = args.has("shot") and not args.has("autoplay")
		if screen.keep_focus:
			m.paused = false
		if args.has("word"):   # preview: this word on top, with words met before (folder tabs)
			m.session.queue.erase(str(args.word))
			m.session.queue.push_front(str(args.word))
			m.shown_id = str(args.word)
			m.sense_reps = int(m.session.records.get(m.shown_id, {}).get("reps", 0))
		for id in str(args.get("met", "")).split(",", false):
			m.session.records[id] = {"reps": 1}
		for id in str(args.get("seen", "")).split(",", false):
			m.session.exposures[id] = 1
		m.tick(ReaderModel.INSERT_TIME)
		if args.has("at"):
			m.tick(float(args.at))
		if args.has("read"):
			m.read()
		if args.has("grade"):
			m.grade(int(args.grade))
		if args.has("scroll"):
			screen.paper.step(0.0)
			screen.paper.scroll.move(float(args.scroll))
			screen.paper.scroll.s = screen.paper.scroll.target
	if screen is LabScreen:
		var lights := {"before": LabScreen.LightState.BEFORE_LAMP, "after": LabScreen.LightState.AFTER_LAMP, "night": LabScreen.LightState.NIGHT}
		if args.has("light") and lights.has(str(args.light)):
			screen.set_light(lights[str(args.light)])
		if args.has("day"):
			screen.set_daytime(true)
	if args.has("shot") and not args.has("autoplay"):
		_take_shot(str(args.shot), int(args.get("wait", 5)))


func _take_shot(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path, " err=", err)
	get_tree().quit(0 if err == OK else 1)
