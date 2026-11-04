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


## Sense to show: reviews rotate through senses (reps % senses, CORE_LOOP §2.2).
func sense(id: String, reps := 0) -> Dictionary:
	var s: Array = word(id).get("senses", [])
	return s[reps % s.size()] if not s.is_empty() else {}
