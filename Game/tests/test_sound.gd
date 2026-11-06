extends RefCounted
## Day 1 sound: files exist for every cue, story lines find their voice, places set the loops.

var t


func _sound() -> Sound:
	var s := Sound.new()
	t.root.add_child(s)
	s.build()
	return s


func test_every_cue_has_a_file() -> void:
	for id in Sound.LINE_SFX:
		t.check(ResourceLoader.exists(Sound.SFX % Sound.LINE_SFX[id]), "sound for " + id)
	for n in ["paper_feed", "scan_pass", "lever", "stamp", "receipt_print", "tick_soft", "tick_key", "drip"]:
		t.check(ResourceLoader.exists(Sound.SFX % n), n)
	for n in ["rain_inside", "rain_outside", "wind", "hum"]:
		t.check(ResourceLoader.exists("res://audio/amb/%s.wav" % n), n)
	t.check(ResourceLoader.exists("res://audio/music/lab_theme.wav"), "music")


func test_story_line_voices() -> void:
	var s := _sound()
	s.line({"id": "D1-027", "speaker": "주인공"})
	t.check(s.voice.stream != null and s.voice.stream.resource_path.ends_with("story_d1_027_a.wav"), "protagonist line → voice A")
	s.line({"id": "D1-106", "speaker": "주임"})
	t.check(s.voice.stream.resource_path.ends_with("story_d1_106.wav"), "chief line → her voice")
	s.free()


func test_day1_words_have_voices() -> void:
	var b := WordBank.load_default()
	for id in b.d1_queue.tutorial + b.d1_queue.task:
		t.check(ResourceLoader.exists(Sound.WORD_VOICE % [id, "term"]), "term voice " + id)


func test_leak_drips_until_patched() -> void:
	var s := _sound()
	s.set_place("lab", true)
	t.check(s.drip_on, "bucket drips under the leak")
	s.cue("D1-312")
	t.check(not s.drip_on, "patched ceiling → quiet")
	s.set_place("outside", true)
	t.check(not s.drip_on, "no bucket outside")
	t.eq(s.place, "outside", "place kept")
	s.free()


func test_loops_wrap() -> void:
	var s := _sound()
	var rain: AudioStreamWAV = s.loops.rain_inside.stream
	t.eq(rain.loop_mode, AudioStreamWAV.LOOP_FORWARD, "rain loops")
	t.check(rain.loop_end > 0, "loop end set")
	s.free()
