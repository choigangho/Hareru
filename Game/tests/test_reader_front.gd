extends RefCounted
## Front reader (v13): paper scroll with rolled ends, scan bar sweep, D-15 wrapping, folder tabs.

var t


func test_scroll_clamps_and_settles() -> void:
	var p := PaperScroll.new()
	p.reset(PaperScroll.VIEW - 10.0)
	t.check(not p.can_scroll(), "short paper does not scroll")
	t.check(not p.move(100.0), "no move on a short paper")
	p.reset(PaperScroll.VIEW + 200.0)
	t.check(p.move(150.0), "moves down")
	p.move(500.0)
	t.eq(p.target, 200.0, "stops at the bottom")
	p.move(-1000.0)
	t.eq(p.target, 0.0, "stops at the top")
	p.move(80.0)
	for i in 120:
		p.tick(1.0 / 60.0)
	t.eq(p.s, 80.0, "glides to the target")


func test_rolled_ends_only() -> void:
	var mid := PaperScroll.row_source(PaperScroll.VIEW / 2.0, 30.0)
	t.eq(mid, Vector2(30.0 + PaperScroll.VIEW / 2.0, 1.0), "middle is flat and lit")
	var edge := PaperScroll.row_source(0.0, 30.0)
	t.check(edge.y < 0.01, "top edge is in shade")
	t.check(edge.x < 30.0, "top roll shows paper above the flat part")
	var bottom := PaperScroll.row_source(PaperScroll.VIEW - 1.0, 0.0)
	t.check(bottom.x > PaperScroll.VIEW - 1.0, "bottom roll shows paper below")
	t.check(bottom.y < 0.3, "bottom edge is dark")
	var flat_start := PaperScroll.row_source(PaperScroll.CURL, 0.0)
	t.eq(flat_start, Vector2(PaperScroll.CURL, 1.0), "roll meets the flat part without a jump")


func test_scan_bar_sweeps_before_each_pass() -> void:
	var s := StudySession.new()
	s.start(["a"])
	var m := ReaderModel.new()
	m.start(s)
	m.tick(0.5)
	m.t = 0.1
	t.check(absf(m.sweep()) < 0.2, "pass 1 starts at the top")
	m.t = 0.69
	t.check(m.sweep() > 0.95, "pass 1 ends at the bottom")
	m.t = 1.5
	t.eq(m.sweep(), -1.0, "parked between passes")


func test_sense_kept_through_the_stamp() -> void:
	var s := StudySession.new()
	s.start(["a", "b"])
	var m := ReaderModel.new()
	m.start(s)
	m.tick(0.5)
	m.tick(4.0)
	m.read()
	m.grade(3)
	t.check(int(s.records.a.reps) > 0, "graduated")
	t.eq(m.sense_reps, 0, "the stamped paper keeps the sense it was read with")


func test_receipt_drops_readings() -> void:
	t.eq(ReaderDesk.plain("あの{山|やま}は{高|たか}い"), "あの山は高い", "no {…|…} on the receipt")
	t.eq(ReaderDesk.wrap_chars("あいうえおかきくけこさ", 10), ["あいうえおかきくけこ", "さ"], "10 per receipt line")


func test_long_example_wraps_then_shrinks() -> void:
	var m := Fonts.mincho()
	var short := ReaderText.fit_example("{駅|えき}まで{歩|ある}く。", m, 428.0)
	t.eq(short.size, 28, "short example stays 28")
	t.eq(short.lines.size(), 1, "on one line")
	var long := ReaderText.fit_example("{答|こた}えが{分|わ}かった{人|ひと}は{手|て}を{挙|あ}げてください。", m, 428.0)
	t.check(long.lines.size() == 2, "long example takes two lines")
	var huge := ReaderText.fit_example("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん。", m, 428.0)
	t.eq(huge.size, 24, "longer than two lines → one step smaller")
	for line in long.lines:
		t.check(not ReaderText.NO_LINE_START.contains(line[0][0].left(1)), "no line starts with punctuation")


func test_ruby_word_stays_whole() -> void:
	var u := ReaderText.ex_units("{今日|きょう}は")
	t.eq(u, [["今日", "きょう"], ["は", ""]], "a word with its reading is one unit")


func test_kanji_mates_learned_first() -> void:
	var b := WordBank.new()
	b.by_id = {
		"w": {"term": "自分", "reading": "じぶん"},
		"a": {"term": "分かる", "reading": "わかる"},
		"b": {"term": "半分", "reading": "はんぶん"},
		"c": {"term": "自転車", "reading": "じてんしゃ"},
		"d": {"term": "水", "reading": "みず"},
		"e": {"term": "十分", "reading": "じゅうぶん"},
	}
	var mates := b.kanji_mates("w", {"b": {}}, {"a": 1, "c": 1, "d": 1})
	t.eq(mates.size(), 3, "three met words share a kanji")
	t.eq(mates[0].id, "b", "learned first")
	t.check(mates[0].learned and not mates[1].learned, "learned / passed")
	var ids := mates.map(func(e): return e.id)
	t.check(not ids.has("e"), "never met → no tab")
	t.check(not ids.has("d"), "no shared kanji → no tab")
	t.eq(b.kanji_mates("d", {}, {"a": 1}), [], "no tabs without a match")


func test_glass_hit_area() -> void:
	t.check(ReaderPaper.on_glass(Vector2(595, 280)), "middle of the paper")
	t.check(not ReaderPaper.on_glass(Vector2(1000, 280)), "monitor is not the paper")
	t.check(not ReaderPaper.on_glass(Vector2(595, 600)), "levers are not the paper")
	for r in ReaderDesk.KEY_RECTS:
		t.check(r.size.x >= 64 and r.size.y >= 64, "lever hit area ≥ 64 (§9)")
