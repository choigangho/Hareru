class_name ReaderDesk
extends Control
## Everything on the front reader (v13) around the glass, drawn at screen resolution:
## the reading log on the receipt, the lever name plates, the folder cards of words that
## share a kanji, the right monitor (chief's face or the kanji) and the stamp.

const KEY_X := [352.0, 520.0, 684.0, 846.0]          # lever centres
const KEY_NAMES := ["모르겠음", "애매함", "알고있음", "쉬움"]
const PLATE_Y := 600.0                                  # name plate under each lever (88 x 32)
# hit areas: the whole lever housing (§9: ≥ 64 px)
const KEY_RECTS := [Rect2(292, 516, 120, 140), Rect2(460, 516, 120, 140), Rect2(624, 516, 120, 140), Rect2(786, 516, 120, 140)]
const RECEIPT := Rect2(40, 166, 176, 276)              # printable part of the receipt
const RECEIPT_LINE := 26.0
const RECEIPT_CHARS := 10
const BOX := Rect2(992, 404, 246, 236)                 # inside of the file box
const MONITOR := Rect2(940, 128, 286, 228)             # right monitor screen
const STAMP_RECT := Rect2(712, 126, 128, 128)          # 32 px stamp at x4, top right of the paper
const FACE_REGION := Rect2(271, 25, 38, 34)            # chief's face in the old monitor sprites
const INK := Color8(40, 30, 30)
const RINK := Color8(70, 60, 50)
const SUB := Color8(110, 100, 85)
const LABEL := Color8(60, 46, 36)
const PH := Color8(150, 230, 150)
const FOLDER := Color8(239, 231, 180)
const FOLDER_FADED := Color8(208, 198, 170)
const BOX_DARK := Color8(78, 48, 32)
const RED := Color8(200, 60, 50)
const GREY := Color8(150, 140, 120)
const TAB_H := 34.0
const STRIP := 30.0
const SLANT := 6.0
const MIN_TAB := 56.0

var model: ReaderModel
var bank: WordBank
var screen: Node                     # ReaderScreen (chief_face, reading_log, flash)
var faces := {}
var stamps := {}


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["calm", "smile", "flustered"]:
		faces[k] = load("res://art/reader/monitor_face_%s.png" % k)
	stamps["doku"] = load("res://art/reader/stamp_doku.png")
	stamps["sai"] = load("res://art/reader/stamp_sai.png")


func _draw() -> void:
	if model == null:
		return
	_draw_receipt()
	_draw_levers()
	_draw_files()
	_draw_monitor()
	_draw_stamp()


## Receipt: other senses of this word after reading (D-15), then the reading log, newest first.
func receipt_lines() -> Array:
	var lines := []
	var P := ReaderModel.Phase
	var id := model.word_id()
	var w := bank.word(id) if id != "" else {}
	var ss: Array = w.get("senses", [])
	if model.phase in [P.READ, P.STAMP] and ss.size() > 1:
		var cur := model.sense_reps % ss.size()
		lines.append("── 다른 뜻 ──")
		for i in ss.size():
			if i == cur:
				continue
			lines.append_array(wrap_chars(str(ss[i].get("meaning", "")), RECEIPT_CHARS))
			lines.append_array(wrap_chars(plain(str(ss[i].get("example", ""))), RECEIPT_CHARS))
		lines.append("")
	lines.append("── 判読 記録 ──")
	for e in screen.reading_log:
		lines.append("No.%04d   %s" % [e.no, e.time])
		lines.append("%s  %s" % [e.term, e.reading] if e.reading != e.term else e.term)
		lines.append("반응   %.1f초" % e.reaction)
		lines.append("판정   %s" % e.key)
		lines.append("- - - - - - - - - -")
	return lines


## Example markup without its readings: {今日|きょう}は → 今日は
static func plain(markup: String) -> String:
	var s := ""
	for seg in Ruby.parse_braces(markup):
		s += seg.base
	return s


static func wrap_chars(s: String, n: int) -> Array:
	var out := []
	while s.length() > n:
		out.append(s.left(n))
		s = s.substr(n)
	if s != "":
		out.append(s)
	return out


func _draw_receipt() -> void:
	var y := RECEIPT.position.y + 10.0
	for line in receipt_lines():
		if y > RECEIPT.end.y:
			break
		var f := Fonts.mincho() if _has_cjk(line) else Fonts.gothic()
		draw_string(f, Vector2(RECEIPT.position.x, y + 6.0), line, HORIZONTAL_ALIGNMENT_LEFT, RECEIPT.size.x, 16, RINK)
		y += RECEIPT_LINE


static func _has_cjk(s: String) -> bool:
	for c in s:
		if c.unicode_at(0) >= 0x3040 and c.unicode_at(0) <= 0x9FFF:
			return true
	return false


func _draw_levers() -> void:
	var P := ReaderModel.Phase
	var lit := model.phase == P.READ
	if screen.stand_blocked_flash > 0.0 and int(screen.stand_blocked_flash * 10) % 2 == 0:
		lit = false
	var g := Fonts.gothic()
	for i in 4:
		var cx: float = KEY_X[i]
		var plate := Rect2(cx - 44.0, PLATE_Y, 88.0, 32.0)
		var down: bool = model.phase == P.STAMP and model.last_key == i + 1
		if lit:
			draw_rect(plate, Color(1.0, 0.86, 0.45, 0.35))
		if down:
			draw_rect(plate, Color(0.2, 0.12, 0.08, 0.22))
			draw_rect(Rect2(cx - 12.0, 528.0, 24.0, 22.0), Color(0.1, 0.07, 0.06, 0.55))   # lever thrown down
		var col := LABEL if lit or down else Color(LABEL, 0.55)
		var w := g.get_string_size(KEY_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(g, Vector2(cx - w / 2.0, PLATE_Y + 22.0 + (2.0 if down else 0.0)), KEY_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)


## Folder cards: after reading, words met before that share a kanji (learned 読, passed 再).
func mates() -> Array:
	var P := ReaderModel.Phase
	if not model.phase in [P.READ, P.STAMP] or model.word_id() == "":
		return []
	return bank.kanji_mates(model.word_id(), model.session.records, model.session.exposures)


func _draw_files() -> void:
	var ms := mates()
	if ms.is_empty():
		return
	draw_rect(BOX, BOX_DARK)
	var stagger := [0.0, 72.0, 140.0]
	for i in ms.size():
		_folder(BOX.position.x + 4.0, BOX.position.y - 2.0 + i * 76.0, BOX.size.x - 8.0, ms[i], stagger[i])


static func tab_width(word: String) -> float:
	return maxf(MIN_TAB, Fonts.mincho().get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 24.0 + 2.0 * SLANT)


func _folder(x: float, y: float, w: float, e: Dictionary, tab_x: float) -> void:
	var fill := FOLDER if e.learned else FOLDER_FADED
	var tw := tab_width(e.term)
	var tx := minf(x + tab_x, x + w - tw)
	var bottom := minf(y + TAB_H + STRIP + 60.0, BOX.end.y)
	var body := Rect2(x, y + TAB_H, w, bottom - y - TAB_H)
	draw_rect(Rect2(body.position + Vector2(6, 6), body.size - Vector2(6, 6)), Color8(30, 18, 14))
	var tab := PackedVector2Array([Vector2(tx, y + TAB_H), Vector2(tx + SLANT, y), Vector2(tx + tw - SLANT, y), Vector2(tx + tw, y + TAB_H)])
	draw_colored_polygon(tab, fill)
	draw_polyline(tab, INK, 4.0)
	draw_rect(body, fill)
	draw_rect(body, INK, false, 4.0)
	draw_rect(Rect2(tx + 4.0, y + TAB_H - 2.0, tw - 8.0, 5.0), fill)   # the tab opens into the card
	var m := Fonts.mincho()
	var ww := m.get_string_size(e.term, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(m, Vector2(tx + (tw - ww) / 2.0, y + TAB_H / 2.0 + 11.0), e.term, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK if e.learned else SUB)
	draw_string(Fonts.gothic(), Vector2(x + 12.0, y + TAB_H + STRIP / 2.0 + 8.0), e.reading, HORIZONTAL_ALIGNMENT_LEFT, w - 50.0, 16, SUB)
	var mark := "読" if e.learned else "再"
	var mw := m.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(m, Vector2(x + w - 14.0 - mw, y + TAB_H + STRIP / 2.0 + 8.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, RED if e.learned else GREY)


## Right monitor: the chief's face while she talks, otherwise the kanji of the paper.
func _draw_monitor() -> void:
	var face: String = screen.chief_face()
	if face != "":
		var sz := FACE_REGION.size * 4.0
		draw_texture_rect_region(faces[face], Rect2(MONITOR.get_center() - sz / 2.0, sz), FACE_REGION)
		return
	if model.phase == ReaderModel.Phase.FINISHED or model.word_id() == "":
		return
	var kanji := ""
	for c in str(bank.word(model.word_id()).get("term", "")):
		if Ruby.is_kanji(c):
			kanji += c
	if kanji == "":
		return
	var sz := 120 if kanji.length() == 1 else (96 if kanji.length() == 2 else 64)
	var m := Fonts.mincho()
	var w := m.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var c := MONITOR.get_center()
	draw_string(m, Vector2(c.x - w / 2.0, c.y + sz * 0.36), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, PH)
	for yy in range(int(MONITOR.position.y), int(MONITOR.end.y), 4):
		draw_rect(Rect2(MONITOR.position.x, yy, MONITOR.size.x, 1), Color(0.03, 0.08, 0.05, 0.45))


func _draw_stamp() -> void:
	if model.phase != ReaderModel.Phase.STAMP:
		return
	draw_texture_rect(stamps.doku if model.stamped_graduated() else stamps.sai, STAMP_RECT, false)
