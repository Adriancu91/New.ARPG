class_name Icons
extends RefCounted
## PLACEHOLDER item and skill icons, drawn procedurally into small textures.
## Each item type has its own glyph; the border shows rarity.

const SIZE := 48
static var _cache: Dictionary = {}


static func for_item(it: Item) -> Texture2D:
	if it == null:
		return null
	var glyph := it.slot
	if it.slot == "weapon":
		glyph = it.weapon_type
	if not it.is_equipment():
		glyph = it.base_id
	var key := "%s_%s" % [glyph, it.rarity if it.is_equipment() else it.kind]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.06, 0.08, 1.0))
	var col := it.display_color()
	_draw_glyph(img, glyph, col.lerp(Color(0.85, 0.82, 0.75), 0.35))
	_border(img, col, 2 if it.is_equipment() and it.rarity != "common" else 1)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func for_skill(sid: String) -> Texture2D:
	if _cache.has("skill_" + sid):
		return _cache["skill_" + sid]
	var sk := DB.get_skill(sid)
	var col: Color = FloatingText.ELEMENT_COLORS.get(sk.get("element", "physical"), Color.WHITE)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(col.darkened(0.82))
	var g := "skill_" + str(sk.get("type", sk.get("kind", "")))
	_draw_glyph(img, g, col)
	_border(img, col if sk.get("kind", "") != "ultimate" else Color(1.0, 0.6, 0.2), 2)
	var tex := ImageTexture.create_from_image(img)
	_cache["skill_" + sid] = tex
	return tex


static func _border(img: Image, c: Color, w: int) -> void:
	for i in w:
		for x in SIZE:
			img.set_pixel(x, i, c)
			img.set_pixel(x, SIZE - 1 - i, c)
			img.set_pixel(i, x, c)
			img.set_pixel(SIZE - 1 - i, x, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, SIZE, SIZE)), c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, thick: int = 2) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in steps:
		var p := a.lerp(b, float(i) / steps)
		_rect(img, int(p.x) - thick / 2, int(p.y) - thick / 2, thick, thick, c)


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color, ring: int = 0) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
				continue
			var d := Vector2(x - cx, y - cy).length()
			if d <= r and (ring == 0 or d >= r - ring):
				img.set_pixel(x, y, c)


static func _draw_glyph(img: Image, glyph: String, c: Color) -> void:
	var d := c.darkened(0.4)
	match glyph:
		"sword":
			_line(img, Vector2(12, 36), Vector2(36, 10), c, 4)
			_line(img, Vector2(10, 28), Vector2(20, 38), d, 3)
			_line(img, Vector2(8, 40), Vector2(13, 35), d, 3)
		"dual_blades":
			_line(img, Vector2(10, 38), Vector2(30, 10), c, 3)
			_line(img, Vector2(38, 38), Vector2(18, 10), c, 3)
		"bow":
			for i in 20:
				var a := lerpf(-1.2, 1.2, i / 19.0)
				_rect(img, int(20 + cos(a) * 14), int(24 + sin(a) * 16), 3, 3, c)
			_line(img, Vector2(25, 9), Vector2(25, 39), d, 1)
		"helmet":
			_circle(img, 24, 26, 13, c)
			_rect(img, 11, 26, 26, 4, d)
			_rect(img, 22, 26, 4, 12, Color(0.07, 0.06, 0.08))
		"armor":
			_rect(img, 14, 12, 20, 26, c)
			_rect(img, 8, 12, 8, 10, d)
			_rect(img, 32, 12, 8, 10, d)
			_rect(img, 21, 12, 6, 6, Color(0.07, 0.06, 0.08))
		"gloves":
			_rect(img, 15, 20, 18, 18, c)
			for i in 4:
				_rect(img, 15 + i * 5, 10, 3, 11, c)
			_rect(img, 33, 22, 6, 4, d)
		"boots":
			_rect(img, 16, 8, 10, 26, c)
			_rect(img, 16, 32, 20, 8, c)
			_rect(img, 14, 8, 14, 3, d)
		"ring":
			_circle(img, 24, 27, 11, c, 4)
			_circle(img, 24, 15, 5, Color(0.6, 0.85, 1.0))
		"amulet":
			_line(img, Vector2(12, 8), Vector2(24, 24), d, 2)
			_line(img, Vector2(36, 8), Vector2(24, 24), d, 2)
			_circle(img, 24, 30, 9, c)
			_circle(img, 24, 30, 4, Color(0.9, 0.3, 0.3))
		"potion_health":
			_rect(img, 20, 8, 8, 8, Color(0.7, 0.65, 0.6))
			_circle(img, 24, 28, 12, Color(0.8, 0.12, 0.18))
			_circle(img, 20, 24, 3, Color(1, 0.6, 0.6))
		"lamp_fragment":
			_line(img, Vector2(14, 38), Vector2(24, 8), c, 4)
			_line(img, Vector2(24, 8), Vector2(34, 30), c, 4)
			_circle(img, 24, 24, 5, Color(1, 0.95, 0.7))
		"skill_melee_cone":
			for i in 7:
				var a := lerpf(-1.0, 1.0, i / 6.0) - PI * 0.5
				_line(img, Vector2(24, 40), Vector2(24 + cos(a) * 20, 40 + sin(a) * 26), c, 2)
		"skill_projectile":
			_line(img, Vector2(8, 40), Vector2(36, 12), c, 3)
			_circle(img, 36, 12, 5, c)
		"skill_multi_projectile":
			for i in 3:
				_line(img, Vector2(10, 40), Vector2(20 + i * 8, 10), c, 2)
		"skill_aoe_target", "skill_aoe_self", "skill_trap":
			_circle(img, 24, 24, 16, c, 3)
			_circle(img, 24, 24, 8, c, 2)
			_circle(img, 24, 24, 3, c)
		"skill_dash_strike":
			for i in 3:
				_line(img, Vector2(8, 16 + i * 8), Vector2(40, 16 + i * 8), c.darkened(i * 0.25), 3)
		"skill_buff":
			_circle(img, 24, 24, 14, c, 3)
			_line(img, Vector2(24, 12), Vector2(24, 36), c, 3)
			_line(img, Vector2(12, 24), Vector2(36, 24), c, 3)
		"skill_passive":
			_circle(img, 24, 24, 12, c, 2)
			_circle(img, 24, 24, 4, c)
		_:
			_circle(img, 24, 24, 9, c)
