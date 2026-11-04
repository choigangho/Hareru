extends RefCounted

var t

const STORY := "res://data/story_n5.json"


func _line(id: String, speaker: String, jp := "", kr := "", branch := 0, options := []) -> Dictionary:
	return {"id": id, "speaker": speaker, "expression": "", "japanese": jp, "korean": kr, "branch": branch, "options": options}


func test_skips_direction_lines() -> void:
	var r := DialogueRunner.new()
	var dirs := []
	r.direction.connect(func(l): dirs.append(l.id))
	r.load_scene([_line("a", "연출"), _line("b", "주임", "", "안녕"), _line("c", "연출"), _line("d", "주인공", "", "네")])
	t.eq(r.current().id, "b", "first shown line")
	r.revealed = r.total_chars()
	r.advance()
	t.eq(r.current().id, "d", "skips direction")
	t.eq(dirs, ["a", "c"], "direction events")


func test_advance_finishes_typing_first() -> void:
	var r := DialogueRunner.new()
	r.load_scene([_line("a", "주임", "", "가나다라마"), _line("b", "주임", "", "x")])
	r.tick(0.05, 40.0)
	t.check(r.is_typing(), "still typing")
	r.advance()
	t.eq(r.current().id, "a", "first press only completes typing")
	t.check(not r.is_typing(), "typing done")
	r.advance()
	t.eq(r.current().id, "b", "second press moves on")


func test_branch_follows_choice() -> void:
	var r := DialogueRunner.new()
	r.load_scene([_line("q", "선택", "", "", 0, ["A", "B"]), _line("a1", "주임", "", "a", 1), _line("b1", "주임", "", "b", 2), _line("end", "주임", "", "끝")])
	t.check(r.is_choice(), "choice line")
	r.advance()
	t.eq(r.current().id, "q", "advance does not skip a choice")
	r.choose(1)
	t.eq(r.current().id, "b1", "branch 2 line")
	r.revealed = r.total_chars()
	r.advance()
	t.eq(r.current().id, "end", "back to shared lines")


func test_meaning_toggle_only_for_japanese() -> void:
	var r := DialogueRunner.new()
	r.load_scene([_line("a", "주임", "はい。", "네."), _line("b", "주임", "", "그냥 한국어")])
	r.toggle_meaning()
	t.check(r.meaning_open, "japanese line opens meaning")
	t.eq(r.meaning(), "네.", "meaning text")
	r.revealed = r.total_chars()
	r.advance()
	t.check(not r.meaning_open, "closed on next line")
	r.toggle_meaning()
	t.check(not r.meaning_open, "korean-only line has no meaning toggle")


func test_names_and_variables() -> void:
	var r := DialogueRunner.new()
	r.vars["이름"] = "하루"
	r.load_scene([_line("a", "주임", "", "{이름} 씨"), _line("b", "주인공", "", "네")])
	t.eq(r.speaker_name(), "주임 연구원", "chief shown by title only")
	t.eq(r.main_text(), "하루 씨", "name variable")
	r.revealed = 99
	r.advance()
	t.eq(r.speaker_name(), "하루", "hero shows player name")


func test_finished_signal() -> void:
	var r := DialogueRunner.new()
	var done := [false]
	r.finished.connect(func(): done[0] = true)
	r.load_scene([_line("a", "주임", "", "끝")])
	r.revealed = 99
	r.advance()
	t.check(done[0] and r.is_done(), "finished at end")


func test_real_t1_scene_loads() -> void:
	var lines := DialogueRunner.scene_from_file(STORY, "D1", "T-1")
	t.check(lines.size() > 30, "T-1 has lines")
	var r := DialogueRunner.new()
	r.load_scene(lines)
	t.eq(r.current().id, "D1-101", "first spoken line after the opening direction")


func test_portrait_mapping() -> void:
	t.eq(DialogScreen.portrait_for("주임", "난감"), "chief_troubled", "chief troubled")
	t.eq(DialogScreen.portrait_for("주임", ""), "chief_default", "no expression -> default")
	t.eq(DialogScreen.portrait_for("독백", ""), "", "monologue has no portrait")
	t.eq(DialogScreen.portrait_for("선택", ""), "hero_default", "choice shows the player")


func test_choice_has_no_name() -> void:
	var r := DialogueRunner.new()
	r.load_scene([_line("q", "선택", "", "", 0, ["A", "B"])])
	t.eq(r.speaker_name(), "", "no speaker name on a choice")


func test_layout_wraps_long_korean() -> void:
	var runs := DialogText.layout(Ruby.parse("가".repeat(60)), Fonts.gothic(), 900)
	t.check(runs.back().y > 0, "wrapped to a second line")


func test_tap_line_opens_meaning_then_advances() -> void:
	var r := DialogueRunner.new()
	r.load_scene([_line("a", "주임", "はい。", "네."), _line("b", "주임", "", "한국어만"), _line("c", "주임", "", "끝")])
	r.tap_line()
	t.check(not r.is_typing(), "first tap finishes typing")
	r.tap_line()
	t.check(r.meaning_open and r.current().id == "a", "second tap opens meaning")
	r.tap_line()
	t.eq(r.current().id, "b", "third tap goes on")
	r.revealed = r.total_chars()
	r.tap_line()
	t.eq(r.current().id, "c", "korean-only line: tap goes on directly")
