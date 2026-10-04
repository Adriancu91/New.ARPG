class_name Menus
extends RefCounted
## Builders for full-screen menus: main menu, character select, pause,
## settings, death screen, lore popup. Each returns a Control.

const T = preload("res://game/ui/ui_theme.gd")


static func _fullscreen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.theme = T.theme()
	return c


static func _centered_column(parent: Control, width: float, x_frac: float = 0.5) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = x_frac
	v.anchor_right = x_frac
	v.offset_left = -width * 0.5
	v.offset_right = width * 0.5
	v.offset_top = -260
	v.offset_bottom = 260
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	parent.add_child(v)
	return v


static func main_menu(main) -> Control:
	var root := _fullscreen()
	root.name = "MainMenu"
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var v := _centered_column(root, 420, 0.27)
	var t := T.title("GLOAMREACH", 64)
	v.add_child(t)
	v.add_child(T.label("Oath of the Ashen Vigil", 20, T.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(T.separator())
	var latest: String = SaveSystem.latest_slot()
	var cont := T.button("Continue", func(): main.continue_game(), 320)
	cont.name = "Continue"
	cont.disabled = latest == ""
	if latest != "":
		cont.tooltip_text = SaveSystem.summary(latest)
	v.add_child(cont)
	var ng := T.button("New Game", func(): main.show_character_select(), 320)
	ng.name = "NewGame"
	v.add_child(ng)
	var load_b := T.button("Load Game", func(): main.show_load_menu(), 320)
	load_b.disabled = latest == ""
	v.add_child(load_b)
	v.add_child(T.button("Settings", func(): main.show_settings(), 320))
	v.add_child(T.button("Quit", func(): main.get_tree().quit(), 320))
	var foot := T.label("v%s  -  Offline single-player  -  Placeholder art & audio" % ProjectSettings.get_setting("application/config/version"), 13, T.TEXT_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(16, -30)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_top = -30
	root.add_child(foot)
	return root


static func load_menu(main) -> Control:
	var root := _fullscreen()
	root.name = "LoadMenu"
	var v := _centered_column(root, 640, 0.3)
	v.add_child(T.title("Load Game", 34))
	for slot in [SaveSystem.MANUAL_SLOT, SaveSystem.AUTO_SLOT]:
		if not SaveSystem.has_save(slot):
			continue
		var label := ("Manual save" if slot == SaveSystem.MANUAL_SLOT else "Autosave") + ":  " + SaveSystem.summary(slot)
		var s: String = slot
		v.add_child(T.button(label, func(): main.load_slot(s), 600))
	v.add_child(T.button("Back", func(): main.show_main_menu(), 600))
	return root


static func character_select(main) -> Control:
	var root := _fullscreen()
	root.name = "CharacterSelect"
	var head := T.title("Choose your Heroine", 40)
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -400
	head.offset_right = 400
	head.offset_top = 24
	root.add_child(head)
	var cards := HBoxContainer.new()
	cards.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cards.anchor_left = 0.5
	cards.anchor_right = 0.5
	cards.anchor_top = 1.0
	cards.anchor_bottom = 1.0
	cards.offset_left = -690
	cards.offset_right = 690
	cards.offset_top = -250
	cards.offset_bottom = -20
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	root.add_child(cards)
	for cid in ["dawnwarden", "hellbrand", "starweaver"]:
		var cls := DB.get_class_data(cid)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(440, 220)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(T.label(cls.hero_name, 22, T.GOLD))
		cv.add_child(T.label("%s  -  %s" % [cls.name, cls.title], 14, T.TEXT_DIM))
		cv.add_child(T.label("%s     Difficulty: %s" % [cls.role, cls.difficulty], 14, Color(cls.palette.glow)))
		var d := T.label(cls.description, 14)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(410, 60)
		cv.add_child(d)
		var c: String = cid
		var row := HBoxContainer.new()
		cv.add_child(row)
		row.add_child(T.button("Preview", func(): main.preview_class(c), 140))
		var start := T.button("Begin as " + cls.hero_name.split(" ")[0], func(): main.start_new_game(c), 220)
		start.name = "Start_" + cid
		row.add_child(start)
		cards.add_child(card)
	var back := T.button("Back", func(): main.show_main_menu(), 140)
	back.position = Vector2(20, 20)
	root.add_child(back)
	return root


static func pause_menu(main) -> Control:
	var root := _fullscreen()
	root.name = "PauseMenu"
	root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	root.add_child(shade)
	var v := _centered_column(root, 360)
	v.add_child(T.title("Paused", 40))
	v.add_child(T.button("Resume", func(): main.set_paused(false), 320))
	v.add_child(T.button("Save Game", func(): main.manual_save(), 320))
	v.add_child(T.button("Load Last Save", func(): main.continue_game(), 320))
	v.add_child(T.button("Settings", func(): main.show_settings(), 320))
	v.add_child(T.button("Quit to Main Menu", func(): main.quit_to_menu(), 320))
	v.add_child(T.button("Quit Game", func(): main.quit_game(), 320))
	var help := T.label("WASD move   LMB attack   RMB heavy attack   Space dodge   Shift block\n1-5 skills   Q potion   E interact   Wheel zoom   F5 quick save", 14, T.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(help)
	return root


static func settings_menu(main) -> Control:
	var root := _fullscreen()
	root.name = "Settings"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.7)
	root.add_child(shade)
	var v := _centered_column(root, 520)
	v.add_child(T.title("Settings", 36))
	for bus in ["Master", "Music", "Ambience", "SFX", "UI"]:
		var row := HBoxContainer.new()
		var l := T.label(bus, 16)
		l.custom_minimum_size.x = 130
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Audio.volumes.get(bus, 0.8)
		s.custom_minimum_size.x = 320
		var b: String = bus
		s.value_changed.connect(func(val): Audio.set_volume(b, val))
		row.add_child(s)
		v.add_child(row)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	v.add_child(fs)
	var dn := CheckButton.new()
	dn.text = "Damage numbers"
	dn.button_pressed = FloatingText.enabled
	dn.toggled.connect(func(on): FloatingText.enabled = on)
	v.add_child(dn)
	var sh := CheckButton.new()
	sh.text = "Camera shake"
	sh.button_pressed = main.camera_shake_enabled
	sh.toggled.connect(func(on): main.camera_shake_enabled = on)
	v.add_child(sh)
	v.add_child(T.button("Back", func(): main.close_settings(), 320))
	return root


static func death_screen(_main) -> Control:
	var root := _fullscreen()
	root.name = "DeathScreen"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.15, 0.0, 0.0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var t := T.title("YOU HAVE FALLEN", 60)
	t.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.anchor_left = 0.5
	t.anchor_right = 0.5
	t.offset_left = -500
	t.offset_right = 500
	root.add_child(t)
	var s := T.label("The dawn is patient. You will rise again at the last waypoint.", 18, T.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.anchor_left = 0.5
	s.anchor_right = 0.5
	s.offset_left = -500
	s.offset_right = 500
	s.offset_top = 60
	root.add_child(s)
	return root


static func lore_popup(main, title: String, text: String) -> Control:
	var root := _fullscreen()
	root.name = "LorePopup"
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(620, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -310
	p.offset_right = 310
	p.offset_top = -150
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(T.title(title, 24))
	var l := T.label(text, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 580
	v.add_child(l)
	v.add_child(T.button("Close", func(): main.close_lore(), 160))
	return root
