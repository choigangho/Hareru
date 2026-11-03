class_name DialogueRunner
extends RefCounted
## Steps through one scene's lines: skips direction lines, follows the chosen branch,
## tracks typing progress and the Korean-meaning toggle. No drawing here (testable).

signal direction(line: Dictionary)   # 연출 lines, for the director to act on later
signal finished

const TEXTLESS := ["연출"]
const NAMES := {"주임": "주임 연구원", "시스템": "NJL-OS", "독백": "", "타자": "", "선택": "", "입력": ""}

var lines: Array = []
var index := -1
var branch := 0
var revealed := 0.0
var meaning_open := false
var vars := {"이름": "신입"}


func load_scene(scene_lines: Array) -> void:
	lines = scene_lines
	index = -1
	branch = 0
	next()


static func scene_from_file(path: String, chapter: String, key: String) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for s in data.chapters[chapter]:
		if s.key == key:
			return s.lines
	return []


func current() -> Dictionary:
	return lines[index] if index >= 0 and index < lines.size() else {}


func is_done() -> bool:
	return index >= lines.size()


## Moves to the next line that should be shown. Returns false at the end of the scene.
func next() -> bool:
	while true:
		index += 1
		if index >= lines.size():
			finished.emit()
			return false
		var l: Dictionary = lines[index]
		if int(l.get("branch", 0)) != 0 and int(l.branch) != branch:
			continue
		if l.speaker in TEXTLESS:
			direction.emit(l)
			continue
		revealed = 0.0
		meaning_open = false
		return true
	return false


func jump_to(line_id: String) -> void:
	for i in lines.size():
		if lines[i].id == line_id:
			index = i
			revealed = 0.0
			meaning_open = false
			return


func is_choice() -> bool:
	return current().get("speaker", "") == "선택" and not current().get("options", []).is_empty()


func choose(option_index: int) -> void:
	branch = option_index + 1
	next()


## Main text of the line: Japanese if present (Korean becomes the tap-to-see meaning).
func main_text() -> String:
	var l := current()
	return fill(l.japanese if l.japanese != "" else l.korean)


func meaning() -> String:
	var l := current()
	return fill(l.korean) if l.japanese != "" else ""


func has_japanese() -> bool:
	return current().get("japanese", "") != ""


func speaker_name() -> String:
	var s: String = current().get("speaker", "")
	if s == "주인공":
		return vars["이름"]
	return NAMES.get(s, s)


func fill(t: String) -> String:
	for k in vars:
		t = t.replace("{%s}" % k, str(vars[k]))
	return t


func total_chars() -> int:
	return Ruby.plain_text(main_text()).length()


func tick(delta: float, chars_per_second := 40.0) -> void:
	revealed = minf(revealed + delta * chars_per_second, total_chars())


func is_typing() -> bool:
	return revealed < total_chars()


## Enter / click: finish typing first, then go on.
func advance() -> void:
	if is_choice():
		return
	if is_typing():
		revealed = total_chars()
	else:
		next()


func toggle_meaning() -> void:
	if has_japanese():
		meaning_open = not meaning_open
