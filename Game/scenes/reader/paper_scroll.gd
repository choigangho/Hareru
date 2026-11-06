class_name PaperScroll
extends RefCounted
## Scrolling the paper on the reader glass (owner 2026-11-04, D-15): the mouse wheel, a
## trackpad's two fingers or the arrow keys move it; only its top and bottom ends roll away.

const VIEW := 334.0          # glass rows the paper fills (screen px)
const CURL := 38.0           # height of each rolled end
const SMOOTH := 0.25         # share of the remaining distance covered per 1/60 s

var content_h := 0.0         # height of what is printed on the paper
var s := 0.0                 # content row at the top of the flat part
var target := 0.0


func max_scroll() -> float:
	return maxf(0.0, content_h - VIEW)


func can_scroll() -> bool:
	return max_scroll() > 0.0


func reset(h: float) -> void:
	content_h = h
	s = 0.0
	target = 0.0


## Move by `px` (positive = further down the paper). Returns false at an end.
func move(px: float) -> bool:
	var next := clampf(target + px, 0.0, max_scroll())
	var moved := not is_equal_approx(next, target)
	target = next
	return moved


func tick(delta: float) -> void:
	var k := 1.0 - pow(1.0 - SMOOTH, delta * 60.0)
	s += (target - s) * k
	if absf(target - s) < 0.3:
		s = target


## For a row `d` px below the top of the glass: which content row shows there and how much
## light it gets (1 = flat, 0 = edge of the roll). The paper wraps a cylinder of radius CURL.
static func row_source(d: float, scroll: float) -> Vector2:
	if d < CURL:
		var a := CURL * asin(minf(1.0, (CURL - d) / CURL))
		return Vector2(scroll + CURL - a, cos(a / CURL))
	if d > VIEW - CURL:
		var a := CURL * asin(minf(1.0, (d - (VIEW - CURL)) / CURL))
		return Vector2(scroll + VIEW - CURL + a, cos(a / CURL))
	return Vector2(scroll + d, 1.0)
