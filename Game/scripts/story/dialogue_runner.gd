class_name DialogueRunner
extends RefCounted
## Steps through one scene's lines: skips direction lines, follows the chosen branch,
## tracks typing progress and the Korean-meaning toggle. No drawing here (testable).

signal direction(line: Dictionary)   # 연출 lines, for the director to act on later
signal cue(line: Dictionary)         # text-less 시스템 lines (a document goes in, a device blinks…)
signal quest_done(line: Dictionary)  # a quest keycap was pressed (D1-312 천장 누수 막기)
signal name_given(player_name: String)
signal finished

const TEXTLESS := ["연출"]
const NAMES := {"주임": "주임 연구원", "시스템": "NJL-OS", "독백": "", "타자": "", "선택": "", "입력": ""}

var lines: Array = []
var index := -1
var branch := 0
var revealed := 0.0
var meaning_open := false
var vars := {"이름": "신입"}
var skip_ids: Array = []   # lines the director ruled out (tutorial key branches)
var hold := false          # a cue listener stopped the dialog here (index stays on the cue line)


## Starts the scene, or continues right after `start_after` (a line id) when resuming.
func load_scene(scene_lines: Array, start_after := "") -> void:
	lines = scene_lines
	index = -1
	branch = 0
	hold = false
	if start_after != "":
		jump_to(start_after)
	next()


static func is_cue(l: Dictionary) -> bool:
	return l.get("speaker", "") == "시스템" and l.get("korean", "") == "" and l.get("japanese", "") == ""


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
	hold = false
	while true:
		index += 1
		if index >= lines.size():
			finished.emit()
			return false
		var l: Dictionary = lines[index]
		if int(l.get("branch", 0)) != 0 and int(l.branch) != branch:
			continue
		if l.id in skip_ids:
			continue
		if l.speaker in TEXTLESS:
			direction.emit(l)
			continue
		if is_cue(l):
			cue.emit(l)
			if hold:
				return false
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
	var l := current()
	return (l.get("speaker", "") == "선택" and not l.get("options", []).is_empty()) or is_quest(l)


## 시스템 line whose note says it is a quest button: one keycap, pressing it does the job.
static func is_quest(l: Dictionary) -> bool:
	return l.get("speaker", "") == "시스템" and str(l.get("note", "")).begins_with("퀘스트 버튼")


## Keycap labels for the current choice (a quest shows its task name, without the cost).
func choice_options() -> Array:
	var l := current()
	if is_quest(l):
		return [str(l.korean).split(" · ")[0]]
	return l.get("options", [])


func choose(option_index: int) -> void:
	if is_quest(current()):
		quest_done.emit(current())
		next()
		return
	branch = option_index + 1
	next()


## 입력 line asking for typed text (D1-141 name). Times / permissions are other 입력 lines.
func is_text_input() -> bool:
	var l := current()
	return l.get("speaker", "") == "입력" and str(l.get("note", "")).begins_with("텍스트 입력")


## The player typed their name (max 8). Empty keeps the current name.
func submit_name(text: String) -> void:
	text = text.strip_edges().left(8)
	if text != "":
		vars["이름"] = text
		name_given.emit(text)
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
	if is_choice() or hold or is_text_input():
		return
	if is_typing():
		revealed = total_chars()
	else:
		next()


func toggle_meaning() -> void:
	if has_japanese():
		meaning_open = not meaning_open


## Touch/click on the text line (§9: everything works by pressing): finish typing →
## open the Korean meaning (Japanese lines) → next line.
func tap_line() -> void:
	if is_choice() or hold or is_text_input():
		return
	if is_typing():
		revealed = total_chars()
	elif has_japanese() and not meaning_open:
		meaning_open = true
	else:
		next()
