class_name Sound
extends Node
## Every sound of Day 1: music, the rain / wind / machine-hum loops, effects and voices.
## main.gd makes one; screens call the static helpers (they do nothing when there is none).
## Files: Game/audio (made by Tools/audio/synth_sounds.py and convert_voice.py).

const SFX := "res://audio/sfx/%s.wav"
const STORY_VOICE := "res://audio/voice/story/story_%s.wav"
const WORD_VOICE := "res://audio/voice/words/%s_%s.wav"
const BUSES := ["Music", "Ambience", "SFX", "Voice"]
const FADE := 0.8
const OFF := -60.0
## Story lines whose note asks for a sound (Docs/03_Story N5_D1).
const LINE_SFX := {"D1-101": "door_creak", "D1-102": "drip", "D1-300": "flip", "D1-302": "tap",
	"D1-312": "patch", "D1-403": "stamp", "D1-414": "door_close", "D1-918": "door_close"}
## Loop levels (dB) per place. drip = the bucket under the leak (until D1-312).
const PLACES := {
	"outside": {"rain_outside": -10.0, "wind": -14.0, "music": OFF, "hum": OFF, "rain_inside": OFF},
	"lab": {"rain_inside": -16.0, "wind": -28.0, "music": -17.0, "hum": OFF, "rain_outside": OFF},
	"reader": {"rain_inside": -24.0, "wind": -34.0, "music": -24.0, "hum": -22.0, "rain_outside": OFF},
	"night": {"rain_outside": -16.0, "wind": -20.0, "music": -20.0, "hum": OFF, "rain_inside": OFF},
}
const DRIP_EVERY := Vector2(2.2, 4.5)   # seconds between drops

static var me: Sound

var loops := {}                         # name -> AudioStreamPlayer
var voice: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var place := ""
var drip_on := false
var _drip_t := 1.0
var _tick_last := -1


func _ready() -> void:
	build()


## Buses and players (also called directly by the headless tests).
func build() -> void:
	if voice:
		return
	me = self
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for n in ["rain_inside", "rain_outside", "wind", "hum"]:
		loops[n] = _loop_player("res://audio/amb/%s.wav" % n, "Ambience")
	loops["music"] = _loop_player("res://audio/music/lab_theme.wav", "Music")
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)


func _exit_tree() -> void:
	for p in loops.values() + pool + [voice]:
		p.stop()   # a stream still held at quit is reported as leaked
		p.stream = null
	if me == self:
		me = null


func _loop_player(path: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := load(path)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	p.stream = s
	p.bus = bus
	p.volume_db = OFF
	add_child(p)
	return p


func _process(delta: float) -> void:
	if drip_on:
		_drip_t -= delta
		if _drip_t <= 0.0:
			_drip_t = randf_range(DRIP_EVERY.x, DRIP_EVERY.y)
			effect("drip", -14.0, 0.06)


## Where we are: crossfades the loops to that place's levels.
func set_place(p: String, leak := false) -> void:
	drip_on = leak and p in ["lab", "reader"]
	if p == place or not PLACES.has(p):
		return
	place = p
	var levels: Dictionary = PLACES[p]
	for n in loops:
		var pl: AudioStreamPlayer = loops[n]
		var target: float = levels.get(n, OFF)
		if target > OFF and not pl.playing:
			pl.volume_db = OFF
			if pl.is_inside_tree():
				pl.play(randf() * maxf(0.0, pl.stream.get_length() - 1.0))
		var tw := create_tween()
		tw.tween_property(pl, "volume_db", target, FADE)
		if target <= OFF:
			tw.tween_callback(pl.stop)


func effect(n: String, db := -6.0, pitch_jitter := 0.0) -> void:
	var path := SFX % n
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = pool[0]
	for q in pool:
		if not q.playing:
			p = q
			break
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if p.is_inside_tree():
		p.play()


## The voice of a story line (protagonist lines use voice A, D1-029), plus its sound cue.
func line(e: Dictionary) -> void:
	var id := str(e.get("id", ""))
	cue(id)
	var key := id.to_lower().replace("-", "_")
	var path := STORY_VOICE % (key + "_a")
	if not ResourceLoader.exists(path):
		path = STORY_VOICE % key
	voice.stop()
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		if voice.is_inside_tree():
			voice.play()
	_tick_last = -1


func cue(id: String) -> void:
	if LINE_SFX.has(id):
		effect(LINE_SFX[id], -4.0)
	if id == "D1-312":
		drip_on = false   # ceiling patched: the bucket goes quiet


## A word on the reader: what = "term" or "s1_example".
func word(id: String, what := "term") -> void:
	var path := WORD_VOICE % [id, what]
	if not ResourceLoader.exists(path):
		return
	voice.stop()
	voice.stream = load(path)
	if voice.is_inside_tree():
		voice.play()


## Typing ticks while a line types out (quiet; none while the line's voice plays).
func typing(revealed: float, key := false) -> void:
	var n := int(revealed)
	if n == _tick_last:
		return
	if n > _tick_last and n % 2 == 0 and not voice.playing:
		effect("tick_key" if key else "tick_soft", -18.0 if not key else -12.0, 0.08)
	_tick_last = n


# static helpers (screens call these; no Sound node = silent)

static func go(p: String, leak := false) -> void:
	if me:
		me.set_place(p, leak)


static func fx(n: String, db := -6.0, pitch_jitter := 0.0) -> void:
	if me:
		me.effect(n, db, pitch_jitter)


static func on_line(e: Dictionary) -> void:
	if me:
		me.line(e)


static func on_direction(l: Dictionary) -> void:
	if me:
		me.cue(str(l.get("id", "")))


static func say_word(id: String, what := "term") -> void:
	if me:
		me.word(id, what)


static func type_tick(revealed: float, key := false) -> void:
	if me:
		me.typing(revealed, key)
