class_name ReaderModel
extends RefCounted
## One document in the reader (CORE_LOOP §2): insert → scan (4 head passes / 10 s) → pull handle
## (reaction time fixed) → key 1-4 → stamp → next. No drawing; the screen reads this state.

enum Phase { INSERT, SCAN, READ, STAMP, FINISHED }

const INSERT_TIME := 0.45
const PASS_TIMES := [0.7, 3.2, 5.7, 8.2]      # clarity steps land at these seconds
const CLARITY := [0.12, 0.35, 0.60, 0.85, 1.0]
const SCAN_END := 10.0
const STAMP_TIME := 0.8
const SWEEP := 0.6                              # one head pass takes this long

signal card_changed(word_id: String)
signal finished

var session: StudySession
var phase: Phase = Phase.INSERT
var t := 0.0                 # seconds in the current phase
var reaction := -1.0         # seconds from scan start to handle pull
var last_grade := 0
var last_key := 0
var shown_id := ""
var paused := false          # window lost focus before reading (C-3)
var _exposure_counted := false
var clock := 0.0             # unix time source for FSRS (set by the screen)
var card_limit := -1         # tutorial: stop after this many stamped cards (-1 = whole pile)
var cards_done := 0
var clock_hold := false      # a tutorial line is up: the scan waits (reaction time stays clean)
var read_count := 0          # handles pulled / keys pressed since this model started
var grade_count := 0


func start(s: StudySession) -> void:
	session = s
	_begin_card()


## The card on the reader. Kept through the stamp even though the pile already moved on.
func word_id() -> String:
	return shown_id


func _begin_card() -> void:
	if session.is_finished() or (card_limit >= 0 and cards_done >= card_limit):
		phase = Phase.FINISHED
		finished.emit()
		return
	phase = Phase.INSERT
	t = 0.0
	reaction = -1.0
	last_key = 0
	shown_id = session.current()
	_exposure_counted = false
	card_changed.emit(shown_id)


## Tutorial: an empty reader until the script puts a document in (no `finished` signal).
func start_empty(s: StudySession) -> void:
	session = s
	phase = Phase.FINISHED
	shown_id = ""


## Tutorial: the script puts this word in now (it goes on top of the pile; one card only).
func insert(word: String) -> void:
	session.queue.erase(word)
	session.queue.push_front(word)
	card_limit = cards_done + 1
	_begin_card()


func tick(delta: float) -> void:
	if paused or (clock_hold and phase == Phase.SCAN):
		return   # a tutorial line only stops the scan clock; the paper still feeds in and stamps
	t += delta
	match phase:
		Phase.INSERT:
			if t >= INSERT_TIME:
				phase = Phase.SCAN
				t = 0.0
				if not _exposure_counted:
					session.show_current()
					_exposure_counted = true
		Phase.STAMP:
			if t >= STAMP_TIME:
				cards_done += 1
				_begin_card()


func clarity() -> float:
	if phase == Phase.INSERT:
		return CLARITY[0]
	if phase != Phase.SCAN:
		return 1.0
	var c: float = CLARITY[0]
	for i in PASS_TIMES.size():
		if t >= PASS_TIMES[i]:
			c = CLARITY[i + 1]
	return c


## Which head frame to show: 0 = parked, 1-4 = scan positions (a pass sweeps 1→4 ending at a pass time).
func head_frame() -> int:
	if phase != Phase.SCAN or t >= SCAN_END:
		return 0
	for pt in PASS_TIMES:
		if t >= pt - SWEEP and t < pt:
			return 1 + int((t - (pt - SWEEP)) / SWEEP * 4.0)
	return 0


func can_read() -> bool:
	return phase == Phase.SCAN


## Handle pulled. Reaction time is fixed here.
func read() -> bool:
	if not can_read():
		return false
	reaction = t
	read_count += 1
	phase = Phase.READ
	t = 0.0
	return true


func can_grade() -> bool:
	return phase == Phase.READ


## Key 1-4 after reading. Returns the hidden grade (or 0 if not allowed now).
func grade(key: int) -> int:
	if not can_grade() or key < 1 or key > 4:
		return 0
	last_key = key
	grade_count += 1
	last_grade = session.submit(key, reaction, clock)
	phase = Phase.STAMP
	t = 0.0
	return last_grade


func stamped_graduated() -> bool:
	return Fsrs.is_graduating(last_grade)


## CORE_LOOP §2.2: after reading, the card must be graded before standing up.
func can_stand_up() -> bool:
	return phase != Phase.READ


## Standing up mid-card: before reading the card goes back on top and the clock is void.
## Returns false (and stays) when a read card still needs its key.
func stand_up() -> bool:
	if not can_stand_up():
		return false
	if phase == Phase.INSERT or phase == Phase.SCAN:
		phase = Phase.INSERT
		t = 0.0
	return true


## C-3: losing window focus before the handle stops the clock; coming back restarts the card.
func focus_lost() -> void:
	if phase == Phase.INSERT or phase == Phase.SCAN:
		paused = true


func focus_gained() -> void:
	if paused:
		paused = false
		phase = Phase.INSERT
		t = 0.0
