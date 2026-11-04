class_name LabScreen
extends Node2D
## The lab cross-section (mock M-1). Draws in art pixels (640x360); the parent scales x2.
## Positions come from Docs/05_Art/Inbox/*.txt and the confirmed mocks (see Game/README.md).

enum LightState { BEFORE_LAMP, AFTER_LAMP, NIGHT }

const FLOOR_Y := 231
const ART := "res://art/"

# name -> [texture, x, y, anchor]. anchor "top" = (x,y) is top-left; "floor" = sits on FLOOR_Y;
# "foot" = bottom of the sprite's opaque box at y (characters).
const PROPS := {
	"leak": ["props/prop_ceiling_leak_stain.png", 302, 33, "top_center"],
	"bucket": ["props/prop_bucket_mid.png", 292, FLOOR_Y, "floor"],
	"clipboard": ["props/prop_clipboard.png", 58, 118, "top"],
	"breaker": ["props/prop_breaker_closed.png", 574, 150, "top"],
	"ledger": ["props/prop_research_ledger.png", 470, 150, "top"],
	"kuro": ["props/kuro_off.png", 222, FLOOR_Y + 2, "floor"],
	"lamp": ["props/prop_desk_lamp_on.png", 331, 207, "floor"],
}
const CHARS := {
	"hero": ["chars/hero_sit_north.png", 142, 233],
	"chief": ["chars/chief_sit_east.png", 309, FLOOR_Y],
}
const HINT_POS := Vector2(208, 197)
const DESK_RECT := Rect2(110, 168, 140, 66)   # hero's desk + reader, art pixels (x2 on screen ≥ 64 px)

var light_state: LightState = LightState.BEFORE_LAMP
var daytime := false
var layers := {}  # name -> CanvasItem, for tests and state changes


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	layers.clear()
	_sprite("background", "lab/lab_section_day1.png", Vector2.ZERO)
	_sprite("window_day", "lab/window/window_day.png", Vector2.ZERO)
	for n in PROPS:
		var p: Array = PROPS[n]
		var tex: Texture2D = load(ART + p[0])
		var pos := Vector2(p[1], p[2])
		match p[3]:
			"floor": pos.y -= tex.get_height()
			"top_center": pos.x -= tex.get_width() / 2
		_sprite(n, p[0], pos)
	for n in CHARS:
		var c: Array = CHARS[n]
		var tex: Texture2D = load(ART + c[0])
		var box := tex.get_image().get_used_rect()
		_sprite(n, c[0], Vector2(c[1], c[2] - box.end.y + 1))
	# light layers (multiply / add) sit above the room and the people;
	# the off tube comes first so the multiply darkens it too
	_sprite("tube_r_off", "lab/light/fluorescent_R_off.png", Vector2(425, 36))
	_sprite("dark_mul", "lab/light/light_dark_mul.png", Vector2.ZERO, CanvasItemMaterial.BLEND_MODE_MUL)
	_sprite("night_mul", "lab/light/light_night_mul.png", Vector2.ZERO, CanvasItemMaterial.BLEND_MODE_MUL)
	_sprite("lamp_pool", "lab/light/lamp_pool_add.png", Vector2.ZERO, CanvasItemMaterial.BLEND_MODE_ADD)
	_sprite("neon_add", "lab/light/light_night_neon_add.png", Vector2.ZERO, CanvasItemMaterial.BLEND_MODE_ADD)
	_sprite("hint", "ui/ui_hint_dot_0.png", HINT_POS)
	apply_state()


## Pressing the glowing desk (or Enter) sits down at the reader (§9: works by pressing).
func _unhandled_input(e: InputEvent) -> void:
	if not layers.has("hint") or not layers.hint.visible:
		return
	var press := e.is_action_pressed("ui_accept")
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		press = desk_screen_rect().has_point(e.position)
	if press:
		EventBus.desk_pressed.emit()


func desk_screen_rect() -> Rect2:
	var xf := get_global_transform_with_canvas()
	return Rect2(xf * DESK_RECT.position, DESK_RECT.size * xf.get_scale())


func set_light(state: LightState) -> void:
	light_state = state
	apply_state()
	if is_inside_tree():
		EventBus.light_changed.emit(state)


func set_daytime(on: bool) -> void:
	daytime = on
	apply_state()


func apply_state() -> void:
	if layers.is_empty():
		return
	var before := light_state == LightState.BEFORE_LAMP
	var night := light_state == LightState.NIGHT
	layers.tube_r_off.visible = before
	layers.dark_mul.visible = before
	layers.lamp.visible = not before
	layers.lamp_pool.visible = not before
	layers.night_mul.visible = night
	layers.neon_add.visible = night
	layers.window_day.visible = daytime and not night


func _sprite(n: String, path: String, pos: Vector2, blend := -1) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = load(ART + path)
	s.centered = false
	s.position = pos
	if blend >= 0:
		var m := CanvasItemMaterial.new()
		m.blend_mode = blend
		s.material = m
	add_child(s)
	layers[n] = s
	return s
