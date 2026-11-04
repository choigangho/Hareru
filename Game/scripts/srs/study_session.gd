class_name StudySession
extends RefCounted
## Today's document pile (CORE_LOOP §2.2). Grades from Fsrs.classify decide where a card goes:
## AGAIN → 2 cards later (+1 failure), HARD → 4 later (+1 failure), HINT → end of pile,
## GOOD and up → graduates (FSRS updated). A word seen 8 times today leaves until tomorrow.

const AGAIN_GAP := 2
const HARD_GAP := 4
const DAILY_EXPOSURE_CAP := 8

signal graduated(word_id: String, state: Dictionary)

var queue: Array = []          # word ids, front = next card
var records := {}              # word id -> FSRS state (persistent part)
var failures := {}             # word id -> failures today
var exposures := {}            # word id -> times shown today
var lapsed_today := {}         # word id -> true when a known word was failed today
var done: Array = []           # graduated today
var deferred: Array = []       # hit the daily cap
var tz_bias_min := 0


func start(ids: Array) -> void:
	queue = ids.duplicate()


func current() -> String:
	return queue[0] if not queue.is_empty() else ""


func is_finished() -> bool:
	return queue.is_empty()


## Called when the card is put in the reader (counts an exposure).
func show_current() -> void:
	var id := current()
	if id != "":
		exposures[id] = int(exposures.get(id, 0)) + 1


## Player pressed key `button` after `elapsed` seconds. Returns the hidden grade.
func submit(button: int, elapsed: float, now: float) -> Fsrs.Grade:
	var id: String = queue.pop_front()
	var g := Fsrs.classify(button, elapsed)
	if Fsrs.is_graduating(g):
		var prev: Dictionary = records.get(id, {})
		var state := Fsrs.graduate(prev, g, lapsed_today.has(id), int(failures.get(id, 0)), now, tz_bias_min)
		records[id] = state
		done.append(id)
		graduated.emit(id, state)
		return g
	if g == Fsrs.Grade.AGAIN or g == Fsrs.Grade.HARD:
		failures[id] = int(failures.get(id, 0)) + 1
		if int(records.get(id, {}).get("reps", 0)) > 0:
			lapsed_today[id] = true
	if int(exposures.get(id, 0)) >= DAILY_EXPOSURE_CAP:
		deferred.append(id)
		return g
	match g:
		Fsrs.Grade.AGAIN: queue.insert(mini(AGAIN_GAP, queue.size()), id)
		Fsrs.Grade.HARD: queue.insert(mini(HARD_GAP, queue.size()), id)
		_: queue.append(id)
	return g
