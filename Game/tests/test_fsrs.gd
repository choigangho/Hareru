extends RefCounted

var t

const B := Fsrs.Key
const G := Fsrs.Grade


func test_classify_table() -> void:
	# CORE_LOOP §2.1 table, column edges 2.5 / 3.5 / 6 / 7 / 10
	var rows := {
		B.AGAIN: [G.AGAIN, G.AGAIN, G.AGAIN, G.AGAIN, G.AGAIN, G.AGAIN],
		B.HARD: [G.HARD, G.HARD, G.HARD, G.HINT_ASSISTED, G.HINT_ASSISTED, G.AGAIN],
		B.GOOD: [G.NEAR_EASY, G.GOOD, G.GOOD, G.HINT_ASSISTED, G.HINT_ASSISTED, G.HINT_ASSISTED],
		B.EASY: [G.EASY, G.EASY, G.NEAR_EASY, G.NEAR_EASY, G.GOOD, G.GOOD],
	}
	var times := [1.0, 3.0, 5.0, 6.5, 8.0, 12.0]
	for b in rows:
		for i in times.size():
			t.eq(Fsrs.classify(b, times[i]), rows[b][i], "button %d at %.1fs" % [b, times[i]])


func test_retrievability_is_90_at_stability() -> void:
	t.check(absf(Fsrs.retrievability(3.0, 3.0) - 0.9) < 1e-9, "R(S,S)=0.9")
	t.eq(Fsrs.retrievability(0.0, 3.0), 1.0, "R at 0 days")


func test_interval_equals_stability_at_90() -> void:
	t.eq(Fsrs.next_interval_days(10.0), 10, "I(S)=S at 0.9 retention")
	t.eq(Fsrs.next_interval_days(1.0, 4), 4, "minimum days")


func test_day_boundary_is_4am() -> void:
	# 2026-11-04 02:00 UTC with bias 0 → belongs to the day that began 2026-11-03 04:00
	var now := 1793757600.0  # 2026-11-04T02:00:00Z
	var start := Fsrs.day_start(now, 0)
	t.eq(Time.get_datetime_string_from_unix_time(int(start)), "2026-11-03T04:00:00", "before 4am = previous day")
	var next := Fsrs.start_of_day_after(now, 1, 0)
	t.eq(Time.get_datetime_string_from_unix_time(int(next)), "2026-11-04T04:00:00", "next day 4am")
	# KST (+540): 2026-11-04 10:00 KST = 01:00Z → day start 2026-11-04 04:00 KST = 2026-11-03T19:00Z
	t.eq(Time.get_datetime_string_from_unix_time(int(Fsrs.day_start(1793754000.0, 540))), "2026-11-03T19:00:00", "KST day start")


func test_new_word_graduation_matches_swift() -> void:
	var s := Fsrs.graduate({}, G.GOOD, false, 0, 0.0, 0)
	t.eq([s.stability, s.difficulty, s.reps, s.interval], [1.0, 5.0, 1, 1], "GOOD first graduation")
	var e := Fsrs.graduate({}, G.EASY, false, 2, 0.0, 0)
	t.eq([e.stability, e.interval], [4.5, 4], "EASY S0 4.5, 4 days")
	t.check(absf(e.difficulty - 3.3) < 1e-9, "difficulty 2.8 + 2*0.25 = 3.3")


func test_review_graduation_grows_stability() -> void:
	var prev := {"stability": 2.0, "difficulty": 5.0, "reps": 1, "lapses": 0, "last_reviewed": 0.0}
	var s := Fsrs.graduate(prev, G.GOOD, false, 0, 2.0 * Fsrs.DAY, 0)
	t.check(s.stability > 2.0, "stability grew")
	t.eq(s.reps, 2, "reps +1")
	t.check(absf(s.difficulty - 5.0) < 1e-9, "GOOD keeps D at mean")


func test_lapse_relearn() -> void:
	var prev := {"stability": 9.0, "difficulty": 5.0, "reps": 3, "lapses": 0, "last_reviewed": 0.0}
	var s := Fsrs.graduate(prev, G.GOOD, true, 2, 10.0 * Fsrs.DAY, 0)
	t.eq(s.lapses, 1, "one lapse")
	t.check(absf(s.stability - 2.55) < 1e-9, "relearn S = sqrt(9)*0.85")
