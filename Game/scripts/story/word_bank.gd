class_name WordBank
extends RefCounted
## Words exported by Tools/export_words_game.py (Game/data/words_n5.json).

const PATH := "res://data/words_n5.json"

var by_id := {}
var d1_queue := {}


static func load_default() -> WordBank:
	var b := WordBank.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for w in data.words:
		b.by_id[w.id] = w
	b.d1_queue = data.d1_queue
	return b


func word(id: String) -> Dictionary:
	return by_id.get(id, {})


## Words sharing a kanji with `id` that the player already met (folder tabs on the reader):
## learned = graduated before (`records`), passed = shown but not graduated (`exposures`).
## Learned first, at most `limit`. Each: {id, term, reading, learned}.
func kanji_mates(id: String, records: Dictionary, exposures: Dictionary, limit := 3) -> Array:
	var kanji := []
	for c in str(word(id).get("term", "")):
		if Ruby.is_kanji(c) and not kanji.has(c):
			kanji.append(c)
	if kanji.is_empty():
		return []
	var learned := []
	var passed := []
	for other in by_id:
		if other == id or not (records.has(other) or exposures.has(other)):
			continue
		var term: String = by_id[other].term
		for c in kanji:
			if term.contains(c):
				var e := {"id": other, "term": term, "reading": by_id[other].reading, "learned": records.has(other)}
				(learned if e.learned else passed).append(e)
				break
	return (learned + passed).slice(0, limit)


## Sense to show: reviews rotate through senses (reps % senses, CORE_LOOP §2.2).
func sense(id: String, reps := 0) -> Dictionary:
	var s: Array = word(id).get("senses", [])
	return s[reps % s.size()] if not s.is_empty() else {}
