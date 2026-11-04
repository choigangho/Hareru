class_name DayEndScreen
extends Node2D
## Day 1 end card (set9 ui_day_end): dark room with the lamp left on (D1-918), then 「1日目 了」
## fades in. Art pixels 640x360; the parent scales x2.

const ART := "res://art/ui/"
const TITLE_CENTRE := Vector2(320, 170)
const TITLE_DELAY := 0.8
const TITLE_FADE := 1.6

var t := 0.0
var title: Sprite2D


func _ready() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(ART + "ui_day_end_bg.png")
	bg.centered = false
	add_child(bg)
	title = Sprite2D.new()
	title.texture = load(ART + "ui_day_end_title.png")
	title.position = TITLE_CENTRE
	add_child(title)
	_apply()


func _process(delta: float) -> void:
	t += delta
	_apply()


func title_alpha() -> float:
	return clampf((t - TITLE_DELAY) / TITLE_FADE, 0.0, 1.0)


func _apply() -> void:
	title.modulate.a = title_alpha()
