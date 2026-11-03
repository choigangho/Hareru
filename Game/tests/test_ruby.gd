extends RefCounted

var t


func test_ruby_segments() -> void:
	var s := Ruby.parse("本当(ほんとう)に、来(き)たんですか?")
	t.eq(s.size(), 4, "segment count")
	t.eq([s[0].base, s[0].ruby], ["本当", "ほんとう"], "first reading")
	t.eq([s[1].base, s[1].ruby], ["に、", ""], "plain between")
	t.eq([s[2].base, s[2].ruby], ["来", "き"], "second reading")


func test_reading_takes_only_trailing_kanji() -> void:
	var s := Ruby.parse("これは名前(なまえ)")
	t.eq([s[0].base, s[1].base, s[1].ruby], ["これは", "名前", "なまえ"], "kana stays outside")


func test_plain_text_matches_word_ranges() -> void:
	# D1-108 tags n5_1523060@0-2 (本当) and n5_1547720@4-6 (来た)
	var p := Ruby.plain_text("本当(ほんとう)に、来(き)たんですか?")
	t.eq(p.substr(0, 2), "本当", "range 0-2")
	t.eq(p.substr(4, 2), "来た", "range 4-6")


func test_emphasis() -> void:
	var s := Ruby.parse("『わかります』か?")
	var emph := ""
	for seg in s:
		if seg.emph:
			emph += seg.base
	t.eq(emph, "『わかります』", "emphasised with brackets")
	t.check(not s.back().emph, "rest not emphasised")


func test_parenthesis_without_kanji_kept() -> void:
	t.eq(Ruby.plain_text("(목 가다듬기)"), "(목 가다듬기)", "no reading for non-kanji")
