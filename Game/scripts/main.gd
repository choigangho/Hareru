extends Node
## Root: owns the GameFlow, swaps the screen node on each state change.
## Test/screenshot args (after `--`): --screen=lab|dialog|reader|leave --light=before|after|night
##   --day --shot=path.png [--wait=frames]
##   dialog: --scene=T-1 (D1 scene key) [--line=D1-108] [--typed] [--meaning]

const ART_SCALE := 2
const STORY := "res://data/story_n5.json"

var flow := GameFlow.new()
var world: Node2D
var screen: Node2D
var args := {}


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	world.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(world)
	flow.changed.connect(_on_flow_changed)
	EventBus.dialog_finished.connect(func(_k): flow.go_to(GameFlow.Screen.LAB))
	args = parse_args(OS.get_cmdline_user_args())
	_show(flow.current)
	_apply_args()


static func parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for a in raw:
		if not a.begins_with("--"):
			continue
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out


func _on_flow_changed(from_screen: int, to_screen: int) -> void:
	_show(to_screen)
	EventBus.screen_changed.emit(from_screen, to_screen)


func _show(s: int) -> void:
	if screen:
		screen.queue_free()
	if s == GameFlow.Screen.LAB:
		screen = LabScreen.new()
	elif s == GameFlow.Screen.DIALOG:
		var key := str(args.get("scene", "T-1"))
		screen = DialogScreen.new()
		screen.setup(DialogueRunner.scene_from_file(STORY, "D1", key), key)
	else:
		screen = preload("res://scenes/placeholder/placeholder_screen.gd").new()
		screen.title = GameFlow.Screen.keys()[s]
	screen.name = "Screen"
	world.add_child(screen)


func _apply_args() -> void:
	if args.has("screen"):
		var s := GameFlow.screen_from_name(str(args.screen))
		if s >= 0 and s != flow.current:
			flow.go_to(s)
	if screen is DialogScreen:
		if args.has("line"):
			screen.runner.jump_to(str(args.line))
			screen._refresh()
		if args.has("typed"):
			screen.runner.revealed = screen.runner.total_chars()
		if args.has("meaning"):
			screen.runner.meaning_open = true
	if screen is LabScreen:
		var lights := {"before": LabScreen.LightState.BEFORE_LAMP, "after": LabScreen.LightState.AFTER_LAMP, "night": LabScreen.LightState.NIGHT}
		if args.has("light") and lights.has(str(args.light)):
			screen.set_light(lights[str(args.light)])
		if args.has("day"):
			screen.set_daytime(true)
	if args.has("shot"):
		_take_shot(str(args.shot), int(args.get("wait", 5)))


func _take_shot(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path, " err=", err)
	get_tree().quit(0 if err == OK else 1)
