class_name HistoryView
extends Control
## "지난 대사" (owner 2026-11-04): today's lines on a big CRT in the dock's style, text only —
## voices are not replayed. Newest at the bottom, just above the line that marks "now".
## Wheel / Up-Down / PageUp-Down scroll, Esc · lower knob · wheel past the end close it.

const BODY := Rect2(120, 24, 1040, 616)
const GLASS := Rect2(150, 52, 980, 560)
const NAME_X := 180
const TEXT_X := 330
const TEXT_W := 740         # ends 40 px before the scroll bar
const TOP := 100
const BOTTOM := 590
const ROW := 52            # one line row; a Japanese line adds a meaning row
const MEANING_ROW := 22

var entries: Array = []    # oldest first, the current line excluded
var scroll := 0            # rows hidden below (0 = newest at the bottom)

signal closed


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP


func row_height(e: Dictionary) -> int:
	return ROW + (MEANING_ROW if str(e.get("meaning", "")) != "" else 0)


func max_scroll() -> int:
	return maxi(0, entries.size() - 1)


func scroll_by(n: int) -> void:
	if n < 0 and scroll == 0:
		closed.emit()     # wheel down past the newest line closes
		return
	scroll = clampi(scroll + n, 0, max_scroll())
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(-1)
		elif e.button_index == MOUSE_BUTTON_LEFT and not BODY.has_point(e.position):
			closed.emit()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_accept"):
		closed.emit()
	elif e.is_action_pressed("ui_up") or (e is InputEventKey and e.pressed and e.keycode == KEY_PAGEUP):
		scroll_by(1)
	elif e.is_action_pressed("ui_down") or (e is InputEventKey and e.pressed and e.keycode == KEY_PAGEDOWN):
		scroll_by(-1)
	else:
		return
	get_viewport().set_input_as_handled()


## One row per line: a line wider than the glass is cut with "…" (TextLine shapes with the
## system fallback fonts, so the width is the real one).
func _row(f: Font, pos: Vector2, t: String, font_size: int, col: Color) -> void:
	var line := TextLine.new()
	line.add_string(t, f, font_size)
	line.width = TEXT_W
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(get_canvas_item(), pos, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(10, 8, 12, 150))
	draw_rect(BODY, Color8(214, 196, 150))
	draw_rect(BODY, Color8(120, 100, 70), false, 4)
	draw_rect(GLASS, Color8(22, 52, 34))
	for y in range(int(GLASS.position.y) + 4, int(GLASS.end.y), 4):
		draw_line(Vector2(GLASS.position.x + 4, y), Vector2(GLASS.end.x - 4, y), Color(0, 0, 0, 0.11))
	var f := Fonts.gothic()
	draw_string(f, Vector2(NAME_X, 64 + f.get_ascent(16)), "지난 대사  ·  휠 / ↑↓ 넘기기  ·  Esc 닫기", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DialogText.PH_DIM)
	if entries.is_empty():
		draw_string(f, Vector2(TEXT_X, 300), "아직 지난 대사가 없어요.", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, DialogText.PH_DIM)
		return
	# fill upwards from the "now" line
	var y := float(BOTTOM)
	draw_line(Vector2(NAME_X, y), Vector2(1100, y), DialogText.PH_DIM, 2)
	var i := entries.size() - 1 - scroll
	while i >= 0:
		var e: Dictionary = entries[i]
		var h := row_height(e)
		if y - h < TOP - 10:
			break
		y -= h
		var who := str(e.get("who", ""))
		if who != "":
			draw_string(f, Vector2(NAME_X, y + 8 + f.get_ascent(16)), who, HORIZONTAL_ALIGNMENT_LEFT, 140, 16, DialogText.AMBER)
		var col := DialogText.CREAM if e.get("speaker", "") in ["독백", "타자"] else DialogText.PH
		_row(f, Vector2(TEXT_X, y + 4), Ruby.plain_text(str(e.text)), 24, col)
		if str(e.get("meaning", "")) != "":
			_row(f, Vector2(TEXT_X, y + ROW - 4), str(e.meaning), 16, DialogText.CREAM)
		i -= 1
	# scroll bar: thumb size = share of rows on screen
	var track := Rect2(1110, 90, 6, 500)
	draw_rect(track, Color8(10, 24, 14))
	var n := entries.size()
	var shown := clampi(int((BOTTOM - TOP) / float(ROW)), 1, n)
	var th := track.size.y * shown / float(n)
	var ty := track.end.y - th - (track.size.y - th) * (scroll / float(maxi(1, max_scroll())))
	draw_rect(Rect2(track.position.x, ty, track.size.x, th), DialogText.PH_DIM)
