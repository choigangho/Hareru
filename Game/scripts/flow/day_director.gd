class_name DayDirector
extends RefCounted
## Runs Day 1 from the first line to leaving work (SLICE_SCOPE "D1 완주"): which screen comes
## next, which scene and line the dialog resumes at, which tutorial card is on the reader, and
## the lab light. No drawing; main.gd asks `screen()` after every event. Saved with to_dict().

enum Phase { DIALOG, CARD, LAB_FREE, TASK, LEAVE }

const SCENES := ["T-0", "T-1", "T-2", "T-3", "T-4", "T-5", "T-6", "T-7", "T-8", "T-9"]
const TASK_AFTER := "T-7"      # D1-715: after this scene the reader glows on the hero's desk
const TASK_RESUME := "D1-800"  # T-8 dialog continues after the 15 cards
const BUCKET_CUE := "D1-308"
const LIGHT_CUES := {
	"D1-802": LabScreen.LightState.AFTER_LAMP,   # lamp installed on the chief's desk
	"D1-900": LabScreen.LightState.NIGHT,        # T-9 night
}

var phase: Phase = Phase.DIALOG
var scene_i := 0
var resume_after := ""     # dialog continues after this line id ("" = scene start)
var card_n := 0            # tutorial card on the reader (1-5)
var light: int = LabScreen.LightState.BEFORE_LAMP
var skip_ids: Array = []   # tutorial key branches already decided (T-2 notes)
var pending: Phase = Phase.TASK   # what pressing the desk resumes from free lab time
var task_started := false
var leak_fixed := false    # D1-312 quest done
var bucket_full := false   # D1-308 the bucket overflows
var player_name := "신입"  # D1-141 typewriter
var tutorial: Array = []   # word ids of documents 1-5
var task: Array = []       # word ids of the 15 task documents


func _init(tutorial_ids: Array = [], task_ids: Array = []) -> void:
	tutorial = tutorial_ids
	task = task_ids


## Debug start at a later scene (--from): sets what the earlier scenes would have changed.
func start_at(key: String) -> void:
	scene_i = maxi(0, SCENES.find(key))
	var after := func(k: String) -> bool: return scene_i > SCENES.find(k)
	bucket_full = after.call("T-3")
	leak_fixed = after.call("T-3")
	if after.call("T-8"):
		light = LabScreen.LightState.AFTER_LAMP


func scene_key() -> String:
	return SCENES[mini(scene_i, SCENES.size() - 1)]


func screen() -> int:
	match phase:
		Phase.DIALOG: return GameFlow.Screen.DIALOG
		Phase.CARD, Phase.TASK: return GameFlow.Screen.READER
		Phase.LEAVE: return GameFlow.Screen.LEAVE
	return GameFlow.Screen.LAB


## Word on the reader for the current tutorial card ("" outside the tutorial).
func card_word() -> String:
	return tutorial[card_n - 1] if phase == Phase.CARD and card_n >= 1 and card_n <= tutorial.size() else ""


## "**문서 3: 分かる**" → 3, otherwise 0.
static func card_number(line: Dictionary) -> int:
	var re := RegEx.create_from_string("^\\*\\*문서 (\\d+)")
	var m := re.search(str(line.get("note", "")))
	return int(m.get_string(1)) if m else 0


## Lines skipped because of the key pressed on tutorial card `card` (1 = 모르겠음).
static func skips_for(card: int, key: int) -> Array:
	if card == 2:
		return ["D1-232", "D1-233"] if key == 1 else ["D1-229", "D1-230", "D1-231"]
	if card == 4 and key == 1:
		return ["D1-240", "D1-241", "D1-242", "D1-243", "D1-244"]
	return []


## A text-less system line reached the dialog. Returns true when the dialog must hold
## (a tutorial document goes into the reader).
func on_cue(line: Dictionary) -> bool:
	var n := card_number(line)
	if n == 0 or phase != Phase.DIALOG:
		return false
	card_n = n
	resume_after = line.id
	phase = Phase.CARD
	return true


## A 연출 line passed. Returns true when the lab looks different now (light, bucket).
func on_direction(line: Dictionary) -> bool:
	var id: String = line.get("id", "")
	if LIGHT_CUES.has(id):
		light = LIGHT_CUES[id]
		return true
	if id == BUCKET_CUE:
		bucket_full = true
		return true
	return false


func on_quest(_line: Dictionary) -> void:
	leak_fixed = true   # Day 1 has one quest: 천장 누수 막기


func on_name(n: String) -> void:
	player_name = n


## One tutorial card was stamped with `key`.
func on_card_done(key: int) -> void:
	if phase != Phase.CARD:
		return
	skip_ids.append_array(skips_for(card_n, key))
	phase = Phase.DIALOG


func on_scene_done() -> void:
	if phase != Phase.DIALOG:
		return
	var key := scene_key()
	resume_after = ""
	if scene_i >= SCENES.size() - 1:
		phase = Phase.LEAVE
		return
	scene_i += 1
	if key == TASK_AFTER:
		resume_after = TASK_RESUME
		pending = Phase.TASK
		phase = Phase.LAB_FREE


## Words to put in the reader when the task starts: what is left of the tutorial pile, then the 15.
func begin_task(left_over: Array) -> Array:
	task_started = true
	var pile := left_over.duplicate()
	for w in task:
		if not w in pile:
			pile.append(w)
	return pile


func on_task_done() -> void:
	if phase == Phase.TASK:
		phase = Phase.DIALOG


## Standing up from the reader leaves the card/pile waiting on the desk.
func on_stand_up() -> void:
	if phase == Phase.CARD or phase == Phase.TASK:
		pending = phase
		phase = Phase.LAB_FREE


## Hero's desk pressed in free lab time. Returns true when it opens the reader.
func on_desk_pressed() -> bool:
	if phase != Phase.LAB_FREE:
		return false
	phase = pending
	return true


func is_desk_waiting() -> bool:
	return phase == Phase.LAB_FREE


func to_dict() -> Dictionary:
	return {"phase": phase, "scene_i": scene_i, "resume_after": resume_after, "card_n": card_n,
		"light": light, "skip_ids": skip_ids.duplicate(), "pending": pending, "task_started": task_started,
		"leak_fixed": leak_fixed, "bucket_full": bucket_full, "player_name": player_name}


func from_dict(d: Dictionary) -> void:
	phase = int(d.get("phase", Phase.DIALOG)) as Phase
	scene_i = int(d.get("scene_i", 0))
	resume_after = str(d.get("resume_after", ""))
	card_n = int(d.get("card_n", 0))
	light = int(d.get("light", LabScreen.LightState.BEFORE_LAMP))
	skip_ids = Array(d.get("skip_ids", []))
	pending = int(d.get("pending", Phase.TASK)) as Phase
	task_started = bool(d.get("task_started", false))
	leak_fixed = bool(d.get("leak_fixed", false))
	bucket_full = bool(d.get("bucket_full", false))
	player_name = str(d.get("player_name", "신입"))
