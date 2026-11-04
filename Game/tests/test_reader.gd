extends RefCounted

var t


func _model(ids := ["a", "b", "c"]) -> ReaderModel:
	var s := StudySession.new()
	s.start(ids)
	var m := ReaderModel.new()
	m.start(s)
	return m


func test_insert_then_scan() -> void:
	var m := _model()
	t.eq(m.phase, ReaderModel.Phase.INSERT, "starts inserting")
	t.check(not m.read(), "cannot read while inserting")
	m.tick(0.5)
	t.eq(m.phase, ReaderModel.Phase.SCAN, "scan after 0.45 s")
	t.eq(m.session.exposures.a, 1, "exposure counted when shown")


func test_clarity_steps() -> void:
	var m := _model()
	m.tick(0.5)
	var seen := []
	for s in [0.1, 1.0, 3.5, 6.0, 9.0]:
		m.t = s
		seen.append(m.clarity())
	t.eq(seen, [0.12, 0.35, 0.60, 0.85, 1.0], "clarity at 0.1/1/3.5/6/9 s")


func test_head_sweeps_before_each_pass() -> void:
	var m := _model()
	m.tick(0.5)
	m.t = 0.15
	t.eq(m.head_frame(), 1, "pass 1 starts top")
	m.t = 0.65
	t.eq(m.head_frame(), 4, "pass 1 ends bottom")
	m.t = 1.5
	t.eq(m.head_frame(), 0, "parked between passes")


func test_reaction_time_and_grade() -> void:
	var m := _model()
	m.tick(0.5)
	m.tick(4.0)
	t.check(m.grade(3) == 0, "no grading before reading")
	t.check(m.read(), "handle pulled")
	t.check(absf(m.reaction - 4.0) < 1e-6, "reaction = time in scan")
	t.eq(m.grade(3), Fsrs.Grade.GOOD, "4 s + 알고있음 = GOOD")
	t.check(m.stamped_graduated(), "判読 stamp")
	t.eq(m.word_id(), "a", "stamped card stays on the reader during the stamp")
	m.tick(1.0)
	t.eq(m.word_id(), "b", "next card")
	t.eq(m.phase, ReaderModel.Phase.INSERT, "inserting next")


func test_again_restamps_and_requeues() -> void:
	var m := _model()
	m.tick(0.5)
	m.read()
	m.grade(1)
	t.check(not m.stamped_graduated(), "再 stamp")
	t.eq(m.session.queue, ["b", "c", "a"], "back in the pile")


func test_stand_up_before_reading_voids_clock() -> void:
	var m := _model()
	m.tick(0.5)
	m.tick(3.0)
	t.check(m.stand_up(), "can stand up while scanning")
	t.eq(m.phase, ReaderModel.Phase.INSERT, "back to insert")
	t.eq(m.word_id(), "a", "same card on top")


func test_finishes_after_last_card() -> void:
	var m := _model(["a"])
	var done := [false]
	m.finished.connect(func(): done[0] = true)
	m.tick(0.5)
	m.read()
	m.grade(4)
	m.tick(1.0)
	t.check(done[0] and m.phase == ReaderModel.Phase.FINISHED, "finished")


func test_brace_ruby() -> void:
	var s := Ruby.parse_braces("ああ、{今日|きょう}もよく{働|はたら}いた。")
	t.eq([s[0].base, s[1].base, s[1].ruby, s[3].base, s[3].ruby], ["ああ、", "今日", "きょう", "働", "はたら"], "brace segments")


func test_word_bank_d1_queue() -> void:
	var b := WordBank.load_default()
	t.eq(b.d1_queue.tutorial.size(), 5, "tutorial 5")
	t.eq(b.d1_queue.task.size(), 15, "task 15")
	t.eq(b.word(b.d1_queue.tutorial[4]).term, "名前", "T-2 fifth card is 名前")
	t.check(b.sense(b.d1_queue.tutorial[0]).has("example"), "sense has example")


func test_cannot_stand_up_between_read_and_grade() -> void:
	var m := _model()
	m.tick(0.5)
	m.read()
	t.check(not m.stand_up(), "grade first (CORE_LOOP §2.2)")
	t.eq(m.phase, ReaderModel.Phase.READ, "still waiting for a key")
	m.grade(3)
	t.check(m.stand_up(), "after the key it is fine")


func test_focus_loss_restarts_card() -> void:
	var m := _model()
	m.tick(0.5)
	m.tick(4.0)
	m.focus_lost()
	m.tick(5.0)
	t.check(m.paused and absf(m.t - 4.0) < 1e-6, "clock stopped while away")
	m.focus_gained()
	t.eq([m.phase, m.t], [ReaderModel.Phase.INSERT, 0.0], "card starts over (C-3)")
	m.tick(0.5)
	t.eq(m.session.exposures.a, 1, "restart is not a second exposure")


func test_focus_loss_after_reading_is_ignored() -> void:
	var m := _model()
	m.tick(0.5)
	m.read()
	m.focus_lost()
	t.check(not m.paused, "reaction time already fixed")
