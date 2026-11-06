class_name ReaderPaper
extends Control
## The paper on the front reader's glass (v13): ReaderText prints into a SubViewport and the
## paper shader lays it on the reclined glass with rolled ends; the scan bar sweeps over it.

const TOPY := 112.0
const BOTY := 446.0
const EDGES := Vector4(352, 838, 334, 854)   # paper edges: top left, top right, bottom left, bottom right
const GLASS := Rect2(318, 98, 546, 362)      # green border of the glass (screen px)
const BAR := Color8(150, 230, 150)
const BAR_PARKED := Color8(86, 140, 92)

var model: ReaderModel
var bank: WordBank
var scroll := PaperScroll.new()
var text: ReaderText
var view: SubViewport
var sheet: ColorRect
var bar: Control
var mat: ShaderMaterial
var _card := ""


static func edges_at(y: float) -> Vector2:
	var t := (y - TOPY) / (BOTY - TOPY)
	return Vector2(lerpf(EDGES.x, EDGES.z, t), lerpf(EDGES.y, EDGES.w, t))


## Is this screen point on the paper (with a little margin for fingers)?
static func on_glass(p: Vector2) -> bool:
	if p.y < TOPY or p.y > BOTY:
		return false
	var e := edges_at(p.y)
	return p.x >= e.x - 14.0 and p.x <= e.y + 14.0


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = SubViewport.new()
	view.size = Vector2i(int(ReaderText.W), ReaderText.TEX_H)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	text = ReaderText.new()
	view.add_child(text)
	sheet = ColorRect.new()
	sheet.position = Vector2(GLASS.position.x, TOPY)
	sheet.size = Vector2(GLASS.size.x, BOTY - TOPY)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/paper.gdshader")
	mat.set_shader_parameter("content", view.get_texture())
	mat.set_shader_parameter("content_size", Vector2(ReaderText.W, ReaderText.TEX_H))
	mat.set_shader_parameter("curl", PaperScroll.CURL)
	mat.set_shader_parameter("top_y", TOPY)
	mat.set_shader_parameter("bot_y", BOTY)
	mat.set_shader_parameter("edges", EDGES)
	mat.set_shader_parameter("rect_pos", sheet.position)
	mat.set_shader_parameter("rect_size", sheet.size)
	sheet.material = mat
	add_child(sheet)
	bar = Control.new()
	bar.size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	add_child(bar)


func step(delta: float) -> void:
	var P := ReaderModel.Phase
	var ph := model.phase
	sheet.visible = ph != P.FINISHED and model.word_id() != ""
	if sheet.visible:
		var id := model.word_id()
		var w := bank.word(id)
		var n: int = maxi(1, w.get("senses", []).size())
		var read := ph in [P.READ, P.STAMP]
		if text.show_card(w, model.sense_reps % n, read) or id != _card:
			if id != _card:
				_card = id
				scroll.reset(text.content_h)
			else:
				scroll.content_h = text.content_h
				scroll.move(0.0)
	scroll.tick(delta)
	var sw := model.sweep()
	var ins := 0.0
	if ph == P.INSERT:
		ins = (1.0 - clampf(model.t / ReaderModel.INSERT_TIME, 0.0, 1.0)) * (BOTY - TOPY)
	mat.set_shader_parameter("scroll", scroll.s)
	mat.set_shader_parameter("content_h", text.content_h)
	mat.set_shader_parameter("ex_top", text.ex_top)
	mat.set_shader_parameter("insert", ins)
	mat.set_shader_parameter("paper_len", maxf(text.content_h, PaperScroll.VIEW))
	mat.set_shader_parameter("clarity", model.clarity())
	mat.set_shader_parameter("scan_y", scan_y(sw))
	bar.queue_redraw()


func scan_y(sw: float) -> float:
	return -1.0 if sw < 0.0 else lerpf(TOPY, BOTY, sw)


func _draw_bar() -> void:
	var y := scan_y(model.sweep()) if model else -1.0
	if y < 0.0:
		var e := edges_at(TOPY)
		bar.draw_rect(Rect2(e.x - 14.0, TOPY - 3.0, e.y - e.x + 28.0, 3.0), BAR_PARKED)
		return
	var e := edges_at(y)
	bar.draw_rect(Rect2(e.x - 14.0, y - 2.0, e.y - e.x + 28.0, 3.0), BAR)
