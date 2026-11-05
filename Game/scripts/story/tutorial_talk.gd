class_name TutorialTalk
extends RefCounted
## T-2 on the reader (owner 2026-11-04): the chief talks while documents 1-5 go through.
## Where the script needs the player (a read, a key) the dialog waits at the reader; while a
## line is up the reader's clock stops so reading subtitles never counts as reaction time.
## Card cues ("**문서 N**") put that word into the reader. No drawing (ReaderScreen draws).

## Shown lines that need the current card read / graded first.
const LINE_WAITS := {"D1-216": "read", "D1-229": "grade", "D1-232": "grade", "D1-235": "read",
	"D1-240": "grade", "D1-245": "grade"}
## Text-less cues that wait (card cues N >= 2 always wait for the previous card's key).
const CUE_WAITS := {"D1-215": "read", "D1-253": "grade"}

var runner := DialogueRunner.new()
var model: ReaderModel
var director: DayDirector
var waiting := ""          # "" | "read" | "grade" — the dialog waits for the player at the reader
var pending_cue := {}      # a cue held until its wait is met
var done := false
var _base_read := 0        # cards already read / graded before this screen (resumed save)
var _base_graded := 0
var _seen_grades := 0

signal finished


func start(lines: Array, start_after := "") -> void:
	_base_read = director.tutorial_graded
	_base_graded = director.tutorial_graded
	director.card_n = director.tutorial_graded
	runner.skip_ids = director.skip_ids
	runner.cue.connect(_on_cue)
	runner.shown.connect(_on_shown)
	runner.finished.connect(_on_finished)
	runner.load_scene(lines, start_after)
	update()


func _on_finished() -> void:
	done = true
	finished.emit()


func read_n() -> int:
	return _base_read + model.read_count


func graded_n() -> int:
	return _base_graded + model.grade_count


func ready_for(kind: String) -> bool:
	if kind == "read":
		return read_n() >= director.card_n
	return graded_n() >= director.card_n


## The dialog is showing a line (the reader waits); false while the player is at the reader.
func is_talking() -> bool:
	return not done and not runner.hold and waiting == "" and not runner.current().is_empty()


func _on_cue(l: Dictionary) -> void:
	var n := DayDirector.card_number(l)
	var need := "grade" if n >= 2 else str(CUE_WAITS.get(l.id, ""))
	if need != "" and not ready_for(need):
		runner.hold = true
		pending_cue = l
		waiting = need
		return
	_do_cue(l)


func _do_cue(l: Dictionary) -> void:
	var n := DayDirector.card_number(l)
	if n > 0 and n <= director.tutorial.size():
		director.card_n = n
		model.insert(director.tutorial[n - 1])


func _on_shown(e: Dictionary) -> void:
	var need := str(LINE_WAITS.get(e.id, ""))
	if need != "" and not ready_for(need):
		waiting = need


## Call every frame and after reader input: lets the dialog go on once the player has done
## what it waited for, tells the director about each key, and holds the reader's clock.
func update() -> void:
	while _seen_grades < model.grade_count:
		_seen_grades += 1
		director.on_card_done(model.last_key)
	if waiting != "" and ready_for(waiting):
		waiting = ""
		if not pending_cue.is_empty():
			var l := pending_cue
			pending_cue = {}
			runner.hold = false
			_do_cue(l)
			runner.next()
		elif runner.current().get("id", "") in runner.skip_ids:
			runner.next()    # the key just decided this branch away (D1-229~233, 240~244)
		else:
			runner.revealed = 0.0
	model.clock_hold = is_talking()
