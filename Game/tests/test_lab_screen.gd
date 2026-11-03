extends RefCounted

var t


func _lab() -> LabScreen:
	var lab := LabScreen.new()
	lab.build()
	return lab


func test_builds_all_layers() -> void:
	var lab := _lab()
	for n in ["background", "window_day", "leak", "bucket", "clipboard", "breaker", "ledger", "kuro", "lamp",
			"hero", "chief", "tube_r_off", "dark_mul", "night_mul", "lamp_pool", "neon_add", "hint"]:
		t.check(lab.layers.has(n) and lab.layers[n].texture != null, "layer %s with texture" % n)
	lab.free()


func test_background_is_art_canvas() -> void:
	var lab := _lab()
	t.eq(lab.layers.background.texture.get_size(), Vector2(640, 360), "art canvas size")
	lab.free()


func test_before_lamp_state() -> void:
	var lab := _lab()
	t.check(lab.layers.dark_mul.visible and lab.layers.tube_r_off.visible, "dark room, right tube off")
	t.check(not lab.layers.lamp.visible and not lab.layers.lamp_pool.visible, "no lamp yet")
	t.check(not lab.layers.night_mul.visible, "not night")
	lab.free()


func test_after_lamp_state() -> void:
	var lab := _lab()
	lab.set_light(LabScreen.LightState.AFTER_LAMP)
	t.check(lab.layers.lamp.visible and lab.layers.lamp_pool.visible, "lamp + pool on")
	t.check(not lab.layers.dark_mul.visible and not lab.layers.tube_r_off.visible, "room lit")
	lab.free()


func test_night_state() -> void:
	var lab := _lab()
	lab.set_light(LabScreen.LightState.NIGHT)
	t.check(lab.layers.night_mul.visible and lab.layers.neon_add.visible and lab.layers.lamp.visible, "night layers")
	lab.set_daytime(true)
	t.check(not lab.layers.window_day.visible, "no daytime window at night")
	lab.free()


func test_blend_modes() -> void:
	var lab := _lab()
	t.eq(lab.layers.dark_mul.material.blend_mode, CanvasItemMaterial.BLEND_MODE_MUL, "dark is multiply")
	t.eq(lab.layers.lamp_pool.material.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "pool is add")
	t.check(lab.layers.tube_r_off.get_index() < lab.layers.dark_mul.get_index(), "tube drawn under the multiply")
	lab.free()


func test_people_stand_on_their_marks() -> void:
	var lab := _lab()
	var chief: Sprite2D = lab.layers.chief
	var box := chief.texture.get_image().get_used_rect()
	t.eq(int(chief.position.y) + box.end.y - 1, LabScreen.FLOOR_Y, "chief feet on floor")
	var bucket: Sprite2D = lab.layers.bucket
	t.eq(int(bucket.position.y + bucket.texture.get_height()), LabScreen.FLOOR_Y, "bucket on floor")
	lab.free()


func test_parse_args() -> void:
	var a: Dictionary = preload("res://scripts/main.gd").parse_args(PackedStringArray(["--shot=x.png", "--day", "junk"]))
	t.eq(a, {"shot": "x.png", "day": true}, "args")
