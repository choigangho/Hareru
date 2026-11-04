extends RefCounted

var t

const PATH := "user://test_save.json"
const NOW := 1793000000.0   # fixed unix time, 2026-10 (tz 0)


func _state() -> Array:
	var d := DayDirector.new(["a", "b"], ["c", "d"])
	var s := StudySession.new()
	s.start(["a", "b", "c"])
	s.show_current()
	s.submit(Fsrs.Key.GOOD, 1.0, NOW)   # a graduates
	s.show_current()
	s.submit(Fsrs.Key.AGAIN, 1.0, NOW)  # b fails once
	d.scene_i = 2
	d.phase = DayDirector.Phase.CARD
	d.card_n = 2
	d.resume_after = "D1-224"
	d.skip_ids = ["D1-229"]
	return [d, s]


func test_round_trip_through_file() -> void:
	var st := _state()
	t.check(SaveGame.write(SaveGame.capture(st[0], st[1], NOW), PATH), "file written")
	var d2 := DayDirector.new(["a", "b"], ["c", "d"])
	var s2 := StudySession.new()
	t.check(SaveGame.restore(SaveGame.read(PATH), d2, s2, NOW + 60.0), "restored")
	t.eq(d2.to_dict(), st[0].to_dict(), "story progress back")
	t.eq(s2.queue, st[1].queue, "today's pile back")
	t.eq(int(s2.failures.b), 1, "failures back")
	t.eq(s2.records.keys(), ["a"], "FSRS records back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_restored_record_still_schedules() -> void:
	var st := _state()
	var d: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.capture(st[0], st[1], NOW)))
	var s2 := StudySession.new()
	SaveGame.restore(d, DayDirector.new(), s2, NOW + 3 * 86400.0)
	s2.start(["a"])
	s2.show_current()
	s2.submit(Fsrs.Key.GOOD, 1.0, NOW + 3 * 86400.0)
	t.eq(int(s2.records.a.reps), 2, "second review counts after JSON (ints came back as floats)")


func test_next_day_drops_today_keeps_records() -> void:
	var st := _state()
	var d := SaveGame.capture(st[0], st[1], NOW)
	var s2 := StudySession.new()
	SaveGame.restore(d, DayDirector.new(), s2, NOW + 86400.0)
	t.check(s2.queue.is_empty() and s2.failures.is_empty(), "yesterday's pile and failures gone after 04:00")
	t.check(s2.records.has("a"), "FSRS records stay")


func test_migrates_v1() -> void:
	var v1 := {"version": 1, "saved_at": NOW, "day_start": Fsrs.day_start(NOW, 0),
		"director": {"phase": DayDirector.Phase.TASK, "scene_i": 8, "task_started": true},
		"session": {"records": {"a": {"reps": 1}}, "queue": ["c"], "failures": {}}}
	var m := SaveGame.migrate(v1)
	t.eq(int(m.version), SaveGame.VERSION, "lifted to current version")
	t.eq(m.records, {"a": {"reps": 1}}, "records moved")
	t.eq(m.today.queue, ["c"], "pile moved")
	var d := DayDirector.new()
	var s := StudySession.new()
	t.check(SaveGame.restore(v1, d, s, NOW), "v1 file restores")
	t.eq(d.phase, DayDirector.Phase.TASK, "story progress from v1")


func test_rejects_unknown_versions() -> void:
	t.check(SaveGame.migrate({}).is_empty(), "no version = unusable")
	t.check(SaveGame.migrate({"version": 99}).is_empty(), "future version = unusable")
	t.check(not SaveGame.restore({"version": 99}, DayDirector.new(), StudySession.new(), NOW), "restore refuses")
