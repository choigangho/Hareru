extends RefCounted
## Day 1 end to end without windows: the real script + word list, a director, a runner and the
## reader model, driven the way main.gd drives the screens.

var t

const STORY := "res://data/story_n5.json"


func _director() -> DayDirector:
	var bank := WordBank.load_default()
	return DayDirector.new(bank.d1_queue.tutorial, bank.d1_queue.task)


## Plays one dialog scene to its end or to a hold. Records shown line ids.
func _play_dialog(d: DayDirector, seen: Array) -> void:
	var r := DialogueRunner.new()
	r.skip_ids = d.skip_ids
	var ended := [false]
	r.cue.connect(func(l):
		if d.on_cue(l):
			r.hold = true)
	r.direction.connect(func(l): d.on_direction(l))
	r.quest_done.connect(d.on_quest)
	r.name_given.connect(d.on_name)
	r.time_given.connect(d.on_work_time)
	r.vars["이름"] = d.player_name
	r.finished.connect(func(): ended[0] = true)
	r.load_scene(DialogueRunner.scene_from_file(STORY, "D1", d.scene_key()), d.resume_after)
	var guard := 0
	while not ended[0] and not r.hold and guard < 500:
		guard += 1
		seen.append(r.current().id)
		if r.is_time_input():
			r.submit_time(510)
		elif r.is_text_input():
			r.submit_name("하루")
		elif r.is_choice():
			r.choose(0)
		else:
			r.revealed = r.total_chars()
			r.advance()
	for c in r.cue.get_connections():   # the lambda holds r: break the cycle
		r.cue.disconnect(c.callable)
	if ended[0]:
		d.on_scene_done()


## Runs the reader until it finishes, pressing `key` on every card. Returns the words shown.
func _play_reader(s: StudySession, m: ReaderModel, key: int) -> Array:
	var shown := []
	var done := [false]
	m.finished.connect(func(): done[0] = true)
	m.start(s)
	var guard := 0
	while not done[0] and guard < 400:
		guard += 1
		m.tick(ReaderModel.INSERT_TIME)
		shown.append(m.word_id())
		m.tick(1.0)
		m.read()
		m.grade(key)
		m.tick(ReaderModel.STAMP_TIME)
	return shown


func test_day_one_start_to_leave() -> void:
	var d := _director()
	var s := StudySession.new()
	s.start(d.tutorial)
	var seen := []
	var cards := []
	var steps := 0
	while d.phase != DayDirector.Phase.LEAVE and steps < 60:
		steps += 1
		match d.phase:
			DayDirector.Phase.DIALOG:
				_play_dialog(d, seen)
			DayDirector.Phase.CARD:
				var w := d.card_word()
				s.queue.erase(w)
				s.queue.push_front(w)
				var m := ReaderModel.new()
				m.card_limit = 1
				cards.append_array(_play_reader(s, m, 3))
				d.on_card_done(m.last_key)
			DayDirector.Phase.LAB_FREE:
				t.check(d.on_desk_pressed(), "desk opens the reader")
			DayDirector.Phase.TASK:
				s.start(d.begin_task(s.queue))
				cards.append_array(_play_reader(s, ReaderModel.new(), 3))
				d.on_task_done()
	t.eq(d.phase, DayDirector.Phase.LEAVE, "Day 1 reaches leaving work")
	t.eq(cards.slice(0, 5), d.tutorial, "tutorial documents in script order")
	t.eq(cards.size(), 20, "5 tutorial + 15 task documents, each once when known")
	t.check("D1-001" in seen or "D1-002" in seen, "intro lines shown")
	t.check("D1-232" in seen and not "D1-229" in seen, "known いいえ takes the 알고있음 branch")
	t.check("D1-240" in seen, "known 見る shows the nameplate lines")
	t.check("D1-803" in seen, "T-8 dialog after the task")
	t.check(not "D1-206" in seen and not "D1-800" in seen, "cue lines are never shown as text")
	t.eq(d.light, LabScreen.LightState.NIGHT, "night by T-9")
	t.eq(s.done.size(), 20, "all 20 graduated")
	t.check(d.leak_fixed and d.bucket_full, "bucket overflowed, then the leak was fixed (D1-308, D1-312)")
	t.eq(d.player_name, "하루", "typed name kept")
	t.check("D1-312" in seen, "quest keycap shown")
	t.eq(d.closeup, "", "memo close-up closed again")
	t.check("D1-404" in seen and "D1-501" in seen, "logbook and switchboard lines after pressing the devices")
	t.check("D1-510" in seen and not "D1-513" in seen, "time set: 510-512, not 513-514")
	t.check("D1-515" in seen and not "D1-519" in seen, "location question gone from the script (D-11)")
	t.eq(d.work_time, 510, "work time kept")


func test_devices_open_panels() -> void:
	var d := _director()
	d.scene_i = DayDirector.SCENES.find("T-4")
	t.check(d.on_cue({"id": "D1-403", "speaker": "시스템"}), "clipboard cue holds the dialog")
	t.eq(d.screen(), GameFlow.Screen.LAB, "back to the lab")
	t.eq(d.target, "clipboard", "the clipboard glows")
	t.check(d.on_desk_pressed(), "pressing it")
	t.eq(d.panel, "logbook", "opens the logbook in the dialog")
	t.eq(d.resume_after, "D1-403", "dialog continues after the cue")
	d.on_direction({"id": "D1-414"})
	t.eq(d.panel, "", "closed when the chief comes back with tea")


func test_memo_closeup_window() -> void:
	var d := _director()
	t.check(d.on_direction({"id": "D1-345"}), "memo opens")
	t.eq(d.closeup, "memo", "")
	t.check(d.on_direction({"id": "D1-357"}), "folded away at D1-357")
	t.eq(d.closeup, "", "")


func test_unknown_keys_take_other_branches() -> void:
	var d := _director()
	d.scene_i = 2   # T-2
	var s := StudySession.new()
	s.start(d.tutorial)
	var seen := []
	while d.scene_key() == "T-2" and d.phase != DayDirector.Phase.LEAVE:
		if d.phase == DayDirector.Phase.DIALOG:
			_play_dialog(d, seen)
		elif d.phase == DayDirector.Phase.CARD:
			var w := d.card_word()
			s.queue.erase(w)
			s.queue.push_front(w)
			var m := ReaderModel.new()
			m.card_limit = 1
			_play_reader(s, m, 1)
			d.on_card_done(1)
	t.check("D1-229" in seen and not "D1-232" in seen, "모르겠음 on いいえ")
	t.check(not "D1-240" in seen and "D1-245" in seen, "모르겠음 on 見る skips 240-244 only")
	t.eq(s.queue.size(), 5, "failed tutorial words stay in the pile")
	var pile := d.begin_task(s.queue)
	t.eq(pile.size(), 20, "left-overs first, then the 15")
	t.eq(pile.slice(0, 5).size(), 5, "")


func test_stand_up_and_desk() -> void:
	var d := _director()
	d.phase = DayDirector.Phase.TASK
	d.on_stand_up()
	t.eq(d.screen(), GameFlow.Screen.LAB, "standing up shows the lab")
	t.check(d.on_desk_pressed(), "desk resumes")
	t.eq(d.phase, DayDirector.Phase.TASK, "back to the task pile")
	t.check(not d.on_desk_pressed(), "desk does nothing outside free time")


func test_after_t7_desk_waits() -> void:
	var d := _director()
	d.scene_i = DayDirector.SCENES.find("T-7")
	d.on_scene_done()
	t.eq(d.screen(), GameFlow.Screen.LAB, "free lab time after T-7")
	t.eq(d.scene_key(), "T-8", "T-8 next")
	t.eq(d.resume_after, "D1-800", "T-8 dialog resumes after the 15 cards")


func test_round_trip_dict() -> void:
	var d := _director()
	d.scene_i = 3
	d.phase = DayDirector.Phase.LAB_FREE
	d.skip_ids = ["D1-232"]
	d.light = LabScreen.LightState.AFTER_LAMP
	d.task_started = true
	var e := _director()
	e.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	t.eq(e.to_dict(), d.to_dict(), "director state survives JSON")


func test_card_number() -> void:
	t.eq(DayDirector.card_number({"note": "**문서 3: 分かる**"}), 3, "")
	t.eq(DayDirector.card_number({"note": "판독 종료"}), 0, "")


func test_start_at_sets_earlier_changes() -> void:
	var d := _director()
	d.start_at("T-6")
	t.eq(d.scene_key(), "T-6", "")
	t.check(d.leak_fixed and d.bucket_full, "T-3 repair already happened")
	t.eq(d.light, LabScreen.LightState.BEFORE_LAMP, "lamp not yet")
	d.start_at("T-9")
	t.eq(d.light, LabScreen.LightState.AFTER_LAMP, "lamp on before T-9")
