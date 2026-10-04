extends TestCase
## Every gameplay action must be reachable from keyboard/mouse (regression:
## build 0.1.0 lost these bindings because the gamepad pass reset them).


func test_every_action_has_keyboard_or_mouse() -> void:
	InputSetup.setup()
	var actions: Array = InputSetup.KEY_ACTIONS.keys() + InputSetup.MOUSE_ACTIONS.keys()
	for a in actions:
		var has_km := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_km = true
		check(has_km, "action '%s' has a keyboard/mouse binding" % a)


func test_expected_default_keys() -> void:
	InputSetup.setup()
	var expect := {"attack": MOUSE_BUTTON_LEFT, "heavy_attack": MOUSE_BUTTON_RIGHT}
	for a in expect:
		var ok := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventMouseButton and ev.button_index == expect[a]:
				ok = true
		check(ok, "%s bound to mouse button %d" % [a, expect[a]])
	var keys := {"skill_1": KEY_1, "interact": KEY_E, "inventory": KEY_I, "dodge": KEY_SPACE, "pause": KEY_ESCAPE, "potion": KEY_Q}
	for a in keys:
		var ok := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and ev.physical_keycode == keys[a]:
				ok = true
		check(ok, "%s bound to key %s" % [a, OS.get_keycode_string(keys[a])])


func test_gamepad_still_bound() -> void:
	InputSetup.setup()
	var ok := false
	for ev in InputMap.action_get_events("attack"):
		if ev is InputEventJoypadButton:
			ok = true
	check(ok, "attack also has a gamepad button")
