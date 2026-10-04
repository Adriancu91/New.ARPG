extends Node
## Registers every input action in code so bindings live in one readable place
## and can later be rebound or extended (controller events are already mapped).

const KEY_ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"dodge": [KEY_SPACE],
	"block": [KEY_SHIFT],
	"interact": [KEY_E],
	"potion": [KEY_Q],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"skill_4": [KEY_4],
	"skill_5": [KEY_5],
	"inventory": [KEY_I, KEY_B],
	"character": [KEY_C],
	"skills_menu": [KEY_K],
	"quest_log": [KEY_J],
	"map": [KEY_M, KEY_TAB],
	"pause": [KEY_ESCAPE],
	"quick_save": [KEY_F5],
}

const MOUSE_ACTIONS := {
	"attack": MOUSE_BUTTON_LEFT,
	"heavy_attack": MOUSE_BUTTON_RIGHT,
	"zoom_in": MOUSE_BUTTON_WHEEL_UP,
	"zoom_out": MOUSE_BUTTON_WHEEL_DOWN,
}

const JOY_BUTTONS := {
	"attack": JOY_BUTTON_X,
	"heavy_attack": JOY_BUTTON_Y,
	"dodge": JOY_BUTTON_B,
	"interact": JOY_BUTTON_A,
	"potion": JOY_BUTTON_DPAD_UP,
	"pause": JOY_BUTTON_START,
	"inventory": JOY_BUTTON_BACK,
	"skill_1": JOY_BUTTON_LEFT_SHOULDER,
	"skill_2": JOY_BUTTON_RIGHT_SHOULDER,
}


func _init() -> void:
	setup()


static func setup() -> void:
	# Reset every action ONCE, then add keyboard, mouse and gamepad events.
	# (Previously each section reset the action again, so the gamepad pass
	# wiped the keyboard/mouse bindings of attack, skills, E, I, Esc...)
	var all_actions: Array = KEY_ACTIONS.keys() + MOUSE_ACTIONS.keys() + JOY_BUTTONS.keys()
	for action in all_actions:
		_ensure(action)
	for action in KEY_ACTIONS:
		for key in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE_ACTIONS:
		var mev := InputEventMouseButton.new()
		mev.button_index = MOUSE_ACTIONS[action]
		InputMap.action_add_event(action, mev)
	for action in JOY_BUTTONS:
		var jev := InputEventJoypadButton.new()
		jev.button_index = JOY_BUTTONS[action]
		InputMap.action_add_event(action, jev)
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in axes:
		var aev := InputEventJoypadMotion.new()
		aev.axis = axes[action][0]
		aev.axis_value = axes[action][1]
		InputMap.action_add_event(action, aev)


static func _ensure(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.25)
