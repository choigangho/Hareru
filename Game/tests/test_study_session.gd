extends RefCounted

var t


func _session(ids: Array) -> StudySession:
	var s := StudySession.new()
	s.start(ids)
	return s


func test_again_goes_two_back() -> void:
	var s := _session(["a", "b", "c", "d"])
	s.show_current()
	t.eq(s.submit(Fsrs.Key.AGAIN, 3.0, 0.0), Fsrs.Grade.AGAIN, "grade")
	t.eq(s.queue, ["b", "c", "a", "d"], "two cards later")
	t.eq(s.failures.a, 1, "failure counted")


func test_hard_goes_four_back() -> void:
	var s := _session(["a", "b", "c", "d", "e", "f"])
	s.submit(Fsrs.Key.HARD, 3.0, 0.0)
	t.eq(s.queue, ["b", "c", "d", "e", "a", "f"], "four cards later")


func test_hint_goes_to_end() -> void:
	var s := _session(["a", "b", "c"])
	s.submit(Fsrs.Key.GOOD, 8.0, 0.0)
	t.eq(s.queue, ["b", "c", "a"], "end of pile")
	t.check(not s.failures.has("a"), "hint is not a failure")


func test_good_graduates_and_records() -> void:
	var s := _session(["a", "b"])
	var seen := []
	s.graduated.connect(func(id, st): seen.append(id))
	s.submit(Fsrs.Key.GOOD, 4.0, 0.0)
	t.eq(s.queue, ["b"], "left the pile")
	t.eq(s.records.a.reps, 1, "record written")
	t.eq(seen, ["a"], "signal")


func test_failures_raise_new_word_difficulty() -> void:
	var s := _session(["a"])
	s.submit(Fsrs.Key.AGAIN, 1.0, 0.0)
	s.submit(Fsrs.Key.GOOD, 4.0, 0.0)
	t.check(absf(s.records.a.difficulty - 5.25) < 1e-9, "one failure bumps D by 0.25")


func test_daily_cap_defers() -> void:
	var s := _session(["a"])
	for i in 8:
		s.show_current()
		if i < 7:
			s.submit(Fsrs.Key.AGAIN, 1.0, 0.0)
	s.submit(Fsrs.Key.AGAIN, 1.0, 0.0)
	t.check(s.is_finished(), "pile empty after cap")
	t.eq(s.deferred, ["a"], "deferred to tomorrow")


func test_known_word_failed_counts_as_lapse() -> void:
	var s := _session(["a"])
	s.records.a = {"stability": 9.0, "difficulty": 5.0, "reps": 3, "lapses": 0, "last_reviewed": 0.0}
	s.submit(Fsrs.Key.AGAIN, 1.0, 10.0 * Fsrs.DAY)
	s.submit(Fsrs.Key.GOOD, 4.0, 10.0 * Fsrs.DAY)
	t.eq(s.records.a.lapses, 1, "lapse recorded at graduation")
