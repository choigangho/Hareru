class_name SaveGame
extends RefCounted
## One save file (roadmap P2 "저장"): FSRS records + today's pile + story progress.
## Persistent: records (FSRS state per word). Today-only: pile, failures, exposures — kept so
## quitting mid-day resumes the same pile, dropped when the 04:00 day boundary has passed.
## Every file carries `version`; migrate() lifts old files step by step to VERSION.

const VERSION := 2
const PATH := "user://save.json"

const SESSION_TODAY := ["queue", "failures", "exposures", "lapsed_today", "done", "deferred"]


static func capture(director: DayDirector, session: StudySession, now: float, tz_bias_min := 0) -> Dictionary:
	var today := {}
	for k in SESSION_TODAY:
		var v = session.get(k)
		today[k] = v.duplicate(true)
	return {
		"version": VERSION,
		"saved_at": now,
		"day_start": Fsrs.day_start(now, tz_bias_min),
		"records": session.records.duplicate(true),
		"today": today,
		"story": {"D1": director.to_dict()},
	}


## Puts a (migrated) save back. Returns false when the file is unusable.
static func restore(d: Dictionary, director: DayDirector, session: StudySession, now: float, tz_bias_min := 0) -> bool:
	d = migrate(d)
	if d.is_empty():
		return false
	session.records = d.get("records", {}).duplicate(true)
	if float(d.get("day_start", -1)) == Fsrs.day_start(now, tz_bias_min):
		var today: Dictionary = d.get("today", {})
		for k in SESSION_TODAY:
			if today.has(k):
				session.set(k, today[k].duplicate(true))
	director.from_dict(d.get("story", {}).get("D1", {}))
	return true


## v1 (first slice build) kept the director at the top level as "director" and the pile as
## "session"; v2 groups story by chapter and splits records from today's pile.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 1 or v > VERSION:
		return {}
	if v == 1:
		var s: Dictionary = d.get("session", {})
		var today := {}
		for k in SESSION_TODAY:
			if s.has(k):
				today[k] = s[k]
		d = {"version": 2, "saved_at": d.get("saved_at", 0.0), "day_start": d.get("day_start", -1.0),
			"records": s.get("records", {}), "today": today, "story": {"D1": d.get("director", {})}}
	return d


static func write(d: Dictionary, path := PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	# write-then-rename: a crash mid-write never leaves a half file as the save
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


static func read(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
