class_name Ruby
extends RefCounted
## Parses a Japanese line with furigana marks: 本当(ほんとう)に、来(き)たんですか?
## → segments [{base, ruby, emph}]. 『…』 marks a learned word (emph, brackets kept).
## Only a run of kanji right before "(" takes the reading.

static func is_kanji(c: String) -> bool:
	var u := c.unicode_at(0)
	return (u >= 0x4E00 and u <= 0x9FFF) or u == 0x3005 or u == 0x3006 or u == 0x30F6


static func parse(text: String) -> Array:
	var segs: Array = []
	var plain := ""
	var emph := false
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "(" or c == "（":
			var close := text.find(")" if c == "(" else "）", i)
			if close > i:
				var k := plain.length()
				while k > 0 and is_kanji(plain[k - 1]):
					k -= 1
				if k < plain.length():
					_push(segs, plain.substr(0, k), "", emph)
					_push(segs, plain.substr(k), text.substr(i + 1, close - i - 1), emph)
					plain = ""
					i = close + 1
					continue
		if c == "『" or c == "』":
			_push(segs, plain, "", emph)
			plain = ""
			if c == "『":
				emph = true
				plain = c
			else:
				_push(segs, c, "", true)
				emph = false
			i += 1
			continue
		plain += c
		i += 1
	_push(segs, plain, "", emph)
	return segs


static func _push(segs: Array, base: String, ruby: String, emph: bool) -> void:
	if base.is_empty():
		return
	segs.append({"base": base, "ruby": ruby, "emph": emph})


## Visible text without readings (word ranges in the story data count these characters).
static func plain_text(text: String) -> String:
	var s := ""
	for seg in parse(text):
		s += seg.base
	return s
