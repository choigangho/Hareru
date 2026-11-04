class_name Fsrs
extends RefCounted
## FSRS memory engine — same numbers as Swift `FSRSEngine` (Sources/Hareru/Services/SRS/FSRSEngine.swift).
## Only change (PROGRESSION P-1): the day starts at 04:00 local time, not midnight.
## Times are unix seconds; `tz_bias_min` = local offset from UTC in minutes (for tests / determinism).

enum Key { AGAIN = 1, HARD = 2, GOOD = 3, EASY = 4 }   # 모르겠음 · 애매함 · 알고있음 · 쉬움
enum Grade { AGAIN = 1, HINT_ASSISTED = 2, HARD = 3, GOOD = 4, NEAR_EASY = 5, EASY = 6 }

const FORGETTING_FACTOR := 19.0 / 81.0
const FORGETTING_DECAY := -0.5
const DESIRED_RETENTION := 0.90
const DAY := 86400.0
const DAY_START_HOUR := 4


static func classify(button: int, elapsed: float) -> Grade:
	var t := maxf(0.0, elapsed)
	match button:
		Key.AGAIN:
			return Grade.AGAIN
		Key.HARD:
			if t < 6.0: return Grade.HARD
			if t < 10.0: return Grade.HINT_ASSISTED
			return Grade.AGAIN
		Key.GOOD:
			if t < 2.5: return Grade.NEAR_EASY
			if t < 6.0: return Grade.GOOD
			return Grade.HINT_ASSISTED
		_:
			if t < 3.5: return Grade.EASY
			if t < 7.0: return Grade.NEAR_EASY
			return Grade.GOOD


static func is_graduating(g: Grade) -> bool:
	return g >= Grade.GOOD


static func retrievability(elapsed_days: float, stability: float) -> float:
	if stability <= 0.0:
		return 0.0
	if elapsed_days <= 0.0:
		return 1.0
	return clampf(pow(1.0 + FORGETTING_FACTOR * (elapsed_days / stability), FORGETTING_DECAY), 0.0, 1.0)


static func next_interval_days(stability: float, minimum_days := 1) -> int:
	var s := maxf(0.1, stability)
	var raw := (s / FORGETTING_FACTOR) * (pow(DESIRED_RETENTION, 1.0 / FORGETTING_DECAY) - 1.0)
	return maxi(minimum_days, int(round(raw)))


## Start of the game day (04:00 local) that contains `now`.
static func day_start(now: float, tz_bias_min: int) -> float:
	var local := now + tz_bias_min * 60.0 - DAY_START_HOUR * 3600.0
	return floor(local / DAY) * DAY - tz_bias_min * 60.0 + DAY_START_HOUR * 3600.0


static func start_of_day_after(now: float, days: int, tz_bias_min: int) -> float:
	return day_start(now, tz_bias_min) + maxi(1, days) * DAY


## Graduation update (grade >= GOOD). prev = {} for a new word, else
## {stability, difficulty, reps, lapses, last_reviewed, due}.
static func graduate(prev: Dictionary, grade: Grade, had_lapse_today: bool, failures: int, now: float, tz_bias_min: int) -> Dictionary:
	assert(is_graduating(grade))
	var min_days: int = {Grade.GOOD: 1, Grade.NEAR_EASY: 2, Grade.EASY: 4}[grade]
	var f := maxi(0, failures)
	if prev.is_empty() or int(prev.get("reps", 0)) <= 0:
		var s0 := _initial_stability(grade)
		var d0 := clampf(_initial_difficulty(grade) + minf(f * 0.25, 1.2), 1.0, 10.0)
		var iv := next_interval_days(s0, min_days)
		return {"stability": s0, "difficulty": d0, "reps": 1, "lapses": 0, "last_reviewed": now,
			"due": start_of_day_after(now, iv, tz_bias_min), "interval": iv}
	var elapsed := maxf(0.0, (now - float(prev.last_reviewed)) / DAY) if prev.has("last_reviewed") else 1.0
	var d := _updated_difficulty(float(prev.difficulty), grade, had_lapse_today, f)
	var s: float
	var lapses: int = int(prev.lapses)
	var ps := float(prev.stability)
	if had_lapse_today:
		lapses += 1
		var base := _initial_stability(grade)
		var retained := pow(maxf(ps, 1.0), 0.5) * _relearn_multiplier(grade)
		s = minf(maxf(base, retained), maxf(base, ps))
	else:
		var r := retrievability(maxf(elapsed, 0.5), ps)
		var growth := exp(0.95) * (11.0 - d) * pow(maxf(ps, 0.5), -0.15) * (exp(0.85 * (1.0 - r)) - 1.0) * _recall_bonus(grade)
		s = maxf(ps * (1.0 + maxf(0.15, growth)), _initial_stability(grade))
	var iv2 := next_interval_days(s, min_days)
	return {"stability": maxf(0.1, s), "difficulty": d, "reps": int(prev.reps) + 1, "lapses": lapses,
		"last_reviewed": now, "due": start_of_day_after(now, iv2, tz_bias_min), "interval": iv2}


static func _initial_stability(g: Grade) -> float:
	return {Grade.GOOD: 1.0, Grade.NEAR_EASY: 2.0, Grade.EASY: 4.5}.get(g, 1.0)


static func _initial_difficulty(g: Grade) -> float:
	return {Grade.GOOD: 5.0, Grade.NEAR_EASY: 4.0, Grade.EASY: 2.8}.get(g, 5.0)


static func _updated_difficulty(cur: float, g: Grade, had_lapse: bool, failures: int) -> float:
	if had_lapse:
		var bump := minf(maxi(0, failures) * 0.20, 0.8)
		var relief := -0.25 if g == Grade.EASY else 0.0
		return clampf(0.10 * 5.0 + 0.90 * (cur + bump + relief), 1.0, 10.0)
	var delta: float = {Grade.GOOD: 0.0, Grade.NEAR_EASY: -0.35, Grade.EASY: -0.75}.get(g, 0.0)
	return clampf(0.10 * 5.0 + 0.90 * (cur + delta), 1.0, 10.0)


static func _recall_bonus(g: Grade) -> float:
	return {Grade.GOOD: 1.00, Grade.NEAR_EASY: 1.22, Grade.EASY: 1.48}.get(g, 1.0)


static func _relearn_multiplier(g: Grade) -> float:
	return {Grade.GOOD: 0.85, Grade.NEAR_EASY: 1.10, Grade.EASY: 1.40}.get(g, 0.85)
