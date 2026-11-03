extends RefCounted

var t


func test_starts_in_lab() -> void:
	t.eq(GameFlow.new().current, GameFlow.Screen.LAB, "start screen")


func test_allowed_transition_emits_once() -> void:
	var f := GameFlow.new()
	var seen := []
	f.changed.connect(func(a, b): seen.append([a, b]))
	t.check(f.go_to(GameFlow.Screen.DIALOG), "lab -> dialog allowed")
	t.eq(f.current, GameFlow.Screen.DIALOG, "now dialog")
	t.eq(seen, [[GameFlow.Screen.LAB, GameFlow.Screen.DIALOG]], "one signal with from/to")


func test_blocked_transition_stays() -> void:
	var f := GameFlow.new()
	f.go_to(GameFlow.Screen.READER)
	var seen := []
	f.changed.connect(func(a, b): seen.append([a, b]))
	t.check(not f.go_to(GameFlow.Screen.LEAVE), "reader -> leave blocked (finish reading first)")
	t.eq(f.current, GameFlow.Screen.READER, "still reader")
	t.eq(seen.size(), 0, "no signal on blocked move")


func test_day_loop() -> void:
	var f := GameFlow.new()
	for s in [GameFlow.Screen.DIALOG, GameFlow.Screen.READER, GameFlow.Screen.LAB, GameFlow.Screen.LEAVE, GameFlow.Screen.LAB]:
		t.check(f.go_to(s), "step to %s" % GameFlow.Screen.keys()[s])


func test_screen_from_name() -> void:
	t.eq(GameFlow.screen_from_name("reader"), GameFlow.Screen.READER, "name lookup")
	t.eq(GameFlow.screen_from_name("nope"), -1, "unknown name")
