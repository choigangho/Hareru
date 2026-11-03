extends Node2D
## Stand-in for screens not built yet (dialog / reader / leave). Draws nothing but a name,
## so the state machine can be exercised end to end. Replaced screen by screen in P2.

var title := ""


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.05, 0.06))
	draw_string(ThemeDB.fallback_font, Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7))
