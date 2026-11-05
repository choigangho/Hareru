class_name DayDirector
extends RefCounted
## Runs Day 1 from the first line to leaving work (SLICE_SCOPE "D1 완주"): which screen comes
## next, which scene and line the dialog resumes at, which tutorial card is on the reader, and
## the lab light. No drawing; main.gd asks `screen()` after every event. Saved with to_dict().

enum Phase { DIALOG, CARD, LAB_FREE, TASK, LEAVE, TUTORIAL }

const SCENES := ["T-0", "T-1", "T-2", "T-3", "T-4", "T-5", "T-6", "T-7", "T-8", "T-9"]
const TASK_AFTER := "T-7"      # D1-715: after this scene the reader glows on the hero's desk
const TASK_RESUME := "D1-800"  # T-8 dialog continues after the 15 cards
const TUTORIAL_SCENE := "T-2"  # played on the reader (TutorialTalk), not over the lab
## Resuming T-2 after a quit: the line just before the next card's cue, by cards graded.
const TUTORIAL_RESUME := {1: "D1-223", 2: "D1-233", 3: "D1-238", 4: "D1-245", 5: "D1-252"}
const BUCKET_CUE := "D1-308"
## Close-up cuts over the lab (art from set8_closeups): shown from one direction line to another.
const CLOSEUP_CUES := {"D1-345": "memo", "D1-357": ""}
## A device blinks on the wall: the dialog waits until the player presses it in the lab,
## then goes on with that device's panel open (subtitle band). Closed by a direction line.
const DEVICE_CUES := {"D1-403": ["clipboard", "logbook"], "D1-500": ["breaker", "settings"]}
const PANEL_CLOSE := ["D1-414"]
## Lines the slice leaves out (none now: the T-5 location question was deleted from the script, D-11).
const SLICE_SKIPS := []
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
var tutorial_graded := 0   # T-2 documents graded so far
var task_started := false
var leak_fixed := false    # D1-312 quest done
var bucket_full := false   # D1-308 the bucket overflows
var player_name := "신입"  # D1-141 typewriter
var closeup := ""          # close-up cut on screen ("" = none)
var panel := ""            # device panel open in the dialog ("logbook" / "settings")
var target := "desk"       # what glows in free lab time: desk / clipboard / breaker
var work_time := -1        # D1-509 minutes after midnight, -1 = later / not set
var history: Array = []    # lines seen today, oldest first (지난 대사), capped at HISTORY_MAX
const HISTORY_MAX := 400
var tutorial: Array = []   # word ids of documents 1-5
var task: Array = []       # word ids of the 15 task documents


func _init(tutorial_ids: Array = [], task_ids: Array = []) -> void:
	tutorial = tutorial_ids
	task = task_ids
	skip_ids = SLICE_SKIPS.duplicate()


## Debug start at a later scene (--from): sets what the earlier scenes would have changed.
func start_at(key: String) -> void:
	scene_i = maxi(0, SCENES.find(key))
	phase = Phase.TUTORIAL if scene_key() == TUTORIAL_SCENE else Phase.DIALOG
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
		Phase.CARD, Phase.TASK, Phase.TUTORIAL: return GameFlow.Screen.READER
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
	if DEVICE_CUES.has(line.get("id", "")) and phase == Phase.DIALOG:
		target = DEVICE_CUES[line.id][0]
		resume_after = line.id
		pending = Phase.DIALOG
		phase = Phase.LAB_FREE
		return true
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
	if id in PANEL_CLOSE:
		panel = ""
		return true
	if CLOSEUP_CUES.has(id):
		closeup = CLOSEUP_CUES[id]
		return true
	if id == BUCKET_CUE:
		bucket_full = true
		return true
	return false


func on_quest(_line: Dictionary) -> void:
	leak_fixed = true   # Day 1 has one quest: 천장 누수 막기


func on_line_shown(e: Dictionary) -> void:
	if not history.is_empty() and history.back().get("id", "") == e.get("id", ""):
		return   # the same line again (screen rebuilt on it)
	history.append(e)
	if history.size() > HISTORY_MAX:
		history.pop_front()


func on_name(n: String) -> void:
	player_name = n


## D1-509: a time keeps 510-512, `나중에` keeps 513-514.
func on_work_time(minutes: int) -> void:
	work_time = minutes
	skip_ids.append_array(["D1-513", "D1-514"] if minutes >= 0 else ["D1-510", "D1-511", "D1-512"])


## One tutorial card was graded with `key`.
func on_card_done(key: int) -> void:
	if phase == Phase.TUTORIAL:
		skip_ids.append_array(skips_for(card_n, key))
		tutorial_graded = maxi(tutorial_graded, card_n)
		resume_after = TUTORIAL_RESUME.get(tutorial_graded, resume_after)
		return
	if phase != Phase.CARD:
		return
	skip_ids.append_array(skips_for(card_n, key))
	phase = Phase.DIALOG


func on_scene_done() -> void:
	if phase != Phase.DIALOG and phase != Phase.TUTORIAL:
		return
	phase = Phase.DIALOG
	var key := scene_key()
	resume_after = ""
	closeup = ""
	panel = ""
	if scene_i >= SCENES.size() - 1:
		phase = Phase.LEAVE
		return
	scene_i += 1
	if key == TASK_AFTER:
		resume_after = TASK_RESUME
		pending = Phase.TASK
		target = "desk"
		phase = Phase.LAB_FREE
	elif scene_key() == TUTORIAL_SCENE:
		phase = Phase.TUTORIAL


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
		target = "desk"
		phase = Phase.LAB_FREE


## The glowing thing (desk / clipboard / breaker) pressed in free lab time. Returns true when
## it opens the next screen (reader, or the dialog with that device's panel).
func on_desk_pressed() -> bool:
	if phase != Phase.LAB_FREE:
		return false
	phase = pending
	if phase == Phase.DIALOG and DEVICE_CUES.has(resume_after):
		panel = DEVICE_CUES[resume_after][1]
	return true


func is_desk_waiting() -> bool:
	return phase == Phase.LAB_FREE


func to_dict() -> Dictionary:
	return {"phase": phase, "scene_i": scene_i, "resume_after": resume_after, "card_n": card_n,
		"light": light, "skip_ids": skip_ids.duplicate(), "pending": pending, "task_started": task_started,
		"leak_fixed": leak_fixed, "bucket_full": bucket_full, "player_name": player_name,
		"closeup": closeup, "panel": panel, "target": target, "work_time": work_time, "tutorial_graded": tutorial_graded,
		"history": history.duplicate(true)}


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
	closeup = str(d.get("closeup", ""))
	panel = str(d.get("panel", ""))
	target = str(d.get("target", "desk"))
	work_time = int(d.get("work_time", -1))
	history = Array(d.get("history", [])).duplicate(true)
	tutorial_graded = int(d.get("tutorial_graded", 0))
