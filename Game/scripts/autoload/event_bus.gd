extends Node
## Global signals so screens never reference each other directly.

signal screen_changed(from_screen: int, to_screen: int)
signal light_changed(light_state: int)
signal dialog_finished(scene_key: String)
signal reading_finished
signal stand_up
