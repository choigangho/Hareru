extends SceneTree
## Headless test runner (no window):
##   godot --headless --path Game -s res://tests/run_tests.gd
## Runs every test_*.gd in res://tests, calling each method named test_*.
## Exit code 0 = all passed.

var failures := 0
var passed := 0
var current := ""


func _initialize() -> void:
	var dir := DirAccess.open("res://tests")
	var files := []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var suite = script.new()
		suite.set("t", self)
		for m in script.get_script_method_list():
			if str(m.name).begins_with("test_"):
				current = "%s::%s" % [f, m.name]
				var before := failures
				var r = suite.call(m.name)
				if r is Object and r.has_method("is_valid"):
					pass
				if failures == before:
					passed += 1
					print("  ok   ", current)
		if suite is Node:
			suite.free()
	print("\n%d passed, %d failed" % [passed, failures])
	quit(1 if failures else 0)


func check(cond: bool, msg := "") -> void:
	if not cond:
		failures += 1
		printerr("  FAIL ", current, " — ", msg)


func eq(a, b, msg := "") -> void:
	check(a == b, "%s (got %s, want %s)" % [msg, a, b])
