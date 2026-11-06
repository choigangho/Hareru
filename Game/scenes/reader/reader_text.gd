class_name ReaderText
extends Control
## What is printed on the reader paper (D-15), drawn into a SubViewport in paper coordinates;
## ReaderPaper lays it on the glass. One sense per paper with all of its examples; the meaning
## line lists every sense with this one bold. Readings, meanings and translations only after
## reading. A long example wraps to two lines, then one font step smaller.

const W := 520.0             # paper width in content px
const TEX_H := 1600          # texture height (content taller than this is cut)
const L := 46.0              # left margin of the examples
const TOP := PaperScroll.CURL + 14.0
const INK := Color8(40, 30, 30)
const SUB := Color8(110, 100, 85)
const RULE := Color8(200, 190, 160)
const FAINT := Color8(228, 220, 188)
const PAPER := Color8(247, 242, 214)
const EX_SIZES := [28, 24]
const EX_LINE := 50.0        # example line pitch (ruby room above each line)
const TR_SIZE := 20
const TR_LINE := 28.0
const NO_LINE_START := "、。，．？！」』）ー"

var word := {}
var sense_i := 0
var read := false
var content_h := 0.0
var ex_top := 0.0


func _ready() -> void:
	size = Vector2(W, TEX_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Print this card. Returns true when the printed layout changed.
func show_card(w: Dictionary, sense: int, is_read: bool) -> bool:
	if w == word and sense == sense_i and is_read == read:
		return false
	word = w
	sense_i = sense
	read = is_read
	_layout()
	queue_redraw()
	return true


func senses() -> Array:
	return word.get("senses", [])


## The examples of the current sense: [{example, translation}].
func examples() -> Array:
	var ss := senses()
	if ss.is_empty():
		return []
	var s: Dictionary = ss[sense_i % ss.size()]
	if s.has("examples"):
		return s.examples
	return [{"example": s.get("example", ""), "translation": s.get("translation", {})}]


## Example markup → printable units: a word with its reading stays whole, plain text splits
## per character. Each unit: [base, ruby].
static func ex_units(markup: String) -> Array:
	var out := []
	for seg in Ruby.parse_braces(markup):
		if seg.ruby != "":
			out.append([seg.base, seg.ruby])
		else:
			for ch in seg.base:
				out.append([ch, ""])
	return out


## Greedy line fill; a unit from NO_LINE_START never starts a line.
static func wrap_units(units: Array, font: Font, size: int, max_w: float) -> Array:
	var lines := [[]]
	var w := 0.0
	for u in units:
		var uw := font.get_string_size(u[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var line: Array = lines[-1]
		if not line.is_empty() and w + uw > max_w and not NO_LINE_START.contains(u[0].left(1)):
			lines.append([u])
			w = uw
		else:
			line.append(u)
			w += uw
	return lines


## D-15: two lines at 28, else one step smaller.
static func fit_example(markup: String, font: Font, max_w: float) -> Dictionary:
	var units := ex_units(markup)
	for sz in EX_SIZES:
		var lines := wrap_units(units, font, sz, max_w)
		if lines.size() <= 2:
			return {"size": sz, "lines": lines}
	return {"size": EX_SIZES[-1], "lines": wrap_units(units, font, EX_SIZES[-1], max_w)}


func _translation_units(tr: Dictionary) -> Array:
	var out := []
	for part in [[tr.get("before", ""), false], [tr.get("answer", ""), true], [tr.get("after", ""), false]]:
		for ch in str(part[0]):
			out.append([ch, part[1]])
	return out


var _blocks := []


func _layout() -> void:
	_blocks.clear()
	var m := Fonts.mincho()
	var g := Fonts.gothic()
	var y := TOP + 196.0
	ex_top = TOP + 166.0
	for ex in examples():
		var fit := fit_example(str(ex.get("example", "")), m, W - 2 * L)
		var tr_lines := wrap_units(_translation_units(ex.get("translation", {})), g, TR_SIZE, W - 2 * L)
		var b := {"y": y, "size": fit.size, "lines": fit.lines, "tr": tr_lines}
		_blocks.append(b)
		y += (fit.lines.size() - 1) * EX_LINE + 42.0 + (tr_lines.size() - 1) * TR_LINE + 30.0 + 40.0
	content_h = minf(y - 40.0 + 30.0 + PaperScroll.CURL, TEX_H)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if word.is_empty():
		return
	var m := Fonts.mincho()
	var g := Fonts.gothic()
	var term: String = word.get("term", "")
	_center(m, term, 64, TOP + 74.0, INK)
	if read:
		if word.get("reading", term) != term:
			_center(g, word.reading, 18, TOP + 16.0, SUB)
		_meaning_line(TOP + 134.0)
	draw_rect(Rect2(L, TOP + 160.0, W - 2 * L, 2), RULE)
	for i in _blocks.size():
		var b: Dictionary = _blocks[i]
		var ly: float = b.y
		for line in b.lines:
			var x := L
			for u in line:
				var uw := m.get_string_size(u[0], HORIZONTAL_ALIGNMENT_LEFT, -1, b.size).x
				draw_string(m, Vector2(x, ly + b.size * 0.36), u[0], HORIZONTAL_ALIGNMENT_LEFT, -1, b.size, INK)
				if read and u[1] != "":
					var rw := g.get_string_size(u[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
					draw_string(g, Vector2(x + (uw - rw) / 2.0, ly - b.size * 0.5 - 4.0), u[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SUB)
				x += uw
			ly += EX_LINE
		ly += 42.0 - EX_LINE
		if read:
			for line in b.tr:
				var x := L
				for u in line:
					var uw := g.get_string_size(u[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TR_SIZE).x
					draw_string(g, Vector2(x, ly + TR_SIZE * 0.36), u[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TR_SIZE, SUB)
					if u[1]:
						draw_rect(Rect2(x, ly + TR_SIZE * 0.36 + 4.0, uw, 1.5), SUB)
					x += uw
				ly += TR_LINE
			ly -= TR_LINE
		else:
			ly += (b.tr.size() - 1) * TR_LINE
		if i < _blocks.size() - 1:
			draw_rect(Rect2(L, ly + 30.0, W - 2 * L, 1), FAINT)


func _center(f: Font, s: String, sz: int, cy: float, c: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(f, Vector2(W / 2.0 - w / 2.0, cy + sz * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


## Every sense, this one bold (more than three: this one, the next, then 「외 N」).
func _meaning_line(cy: float) -> void:
	var ss := senses()
	if ss.is_empty():
		return
	var cur := sense_i % ss.size()
	var parts := []
	var order := range(ss.size())
	if ss.size() > 3:
		order = [cur, (cur + 1) % ss.size()]
	for i in order:
		parts.append([str(ss[i].get("meaning", "")), i == cur])
	if ss.size() > 3:
		parts.append(["외 %d" % (ss.size() - 2), false])
	var sep := "  ·  "
	var sz := 22
	var total := _parts_w(parts, sep, sz)
	if total > W - 2 * L:
		sz = 18
		total = _parts_w(parts, sep, sz)
	var x := W / 2.0 - total / 2.0
	var base := cy + sz * 0.36
	for i in parts.size():
		if i > 0:
			draw_string(Fonts.gothic(), Vector2(x, base), sep, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, SUB)
			x += Fonts.gothic().get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var f := Fonts.gothic_bold() if parts[i][1] else Fonts.gothic()
		draw_string(f, Vector2(x, base), parts[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, INK if parts[i][1] else SUB)
		x += f.get_string_size(parts[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


func _parts_w(parts: Array, sep: String, sz: int) -> float:
	var w := 0.0
	for i in parts.size():
		if i > 0:
			w += Fonts.gothic().get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var f := Fonts.gothic_bold() if parts[i][1] else Fonts.gothic()
		w += f.get_string_size(parts[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	return w
