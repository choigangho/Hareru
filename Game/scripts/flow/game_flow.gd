class_name GameFlow
extends RefCounted
## The one screen state machine of the game (roadmap P2 "게임 흐름").

enum Screen { LAB, DIALOG, READER, LEAVE }

signal changed(from_screen: Screen, to_screen: Screen)

const ALLOWED := {
	Screen.LAB: [Screen.DIALOG, Screen.READER, Screen.LEAVE],
	Screen.DIALOG: [Screen.LAB, Screen.READER, Screen.LEAVE],
	Screen.READER: [Screen.LAB, Screen.DIALOG],
	Screen.LEAVE: [Screen.LAB],  # next morning
}

var current: Screen = Screen.LAB


func can_go(to_screen: Screen) -> bool:
	return to_screen in ALLOWED[current]


## Returns false (and stays put) for a transition the flow does not allow.
func go_to(to_screen: Screen) -> bool:
	if not can_go(to_screen):
		return false
	var from_screen := current
	current = to_screen
	changed.emit(from_screen, to_screen)
	return true


static func screen_from_name(screen_name: String) -> int:
	var key := screen_name.to_upper()
	return Screen[key] if Screen.has(key) else -1
