class_name HeroModels
extends RefCounted
## PLACEHOLDER heroine models assembled from primitives (front = +Z inside the
## rig). They establish silhouette, palette and identity for each heroine
## until authored 3D models replace them (see ART_DIRECTION.md).

const K = preload("res://game/characters/model_kit.gd")


static func build(class_id: String) -> HumanoidRig:
	var cls := DB.get_class_data(class_id)
	var p: Dictionary = cls.palette
	var rig := HumanoidRig.new()
	rig.name = "Rig"
	rig.build_skeleton(0.95, 0.2, 1.44, 0.105)
	var pal := {}
	for k in p:
		pal[k] = Color(p[k])
	_body(rig, pal, class_id)
	match class_id:
		"dawnwarden": _dawnwarden(rig, pal)
		"hellbrand": _hellbrand(rig, pal)
		"starweaver": _starweaver(rig, pal)
	return rig


## Shared adult female base: long legs, defined waist, fuller hips.
static func _body(rig: HumanoidRig, c: Dictionary, class_id: String) -> void:
	var skin := K.mat(c.skin, 0.0, 0.55)
	var armor := K.mat(c.primary, 0.0, 0.35, 0.75)
	var dark := K.mat(c.secondary, 0.0, 0.6, 0.3)
	var trim := K.mat(c.accent, 0.15, 0.3, 0.9)
	# legs: thigh (skin) + tall boots
	for leg in [rig.leg_l, rig.leg_r]:
		K.limb(leg, 0.078, 0.06, 0.42, skin)
		var boot_top := -0.42
		K.part(leg, K.cyl(0.066, 0.055, 0.5), dark, Vector3(0, boot_top - 0.25 + 0.04, 0))
		K.part(leg, K.torus(0.055, 0.075), trim, Vector3(0, boot_top + 0.02, 0))
		K.part(leg, K.box(Vector3(0.1, 0.06, 0.2)), dark, Vector3(0, -0.92, 0.04))
		K.part(leg, K.prism(Vector3(0.07, 0.12, 0.04)), trim, Vector3(0, -0.4, 0.06), Vector3(0, 0, 180))
	# hips and armored skirt
	K.part(rig.hips, K.sphere(0.2), dark, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.62, 0.72))
	K.part(rig.hips, K.cyl(0.165, 0.245, 0.2, 10), armor, Vector3(0, -0.04, 0))
	for i in 6:
		var a := deg_to_rad(-75 + i * 30)
		K.part(rig.hips, K.box(Vector3(0.11, 0.2, 0.02)), trim if i % 2 == 0 else armor,
			Vector3(sin(a) * 0.235, -0.1, cos(a) * 0.235), Vector3(-12, rad_to_deg(a), 0))
	# waist + corset torso
	K.part(rig.torso, K.cyl(0.105, 0.135, 0.14), dark, Vector3(0, 0.13, 0))
	K.part(rig.torso, K.cyl(0.17, 0.11, 0.28), armor, Vector3(0, 0.33, 0))
	# breastplate (armored, fully covered)
	K.part(rig.torso, K.sphere(0.13), armor, Vector3(0, 0.39, 0.05), Vector3.ZERO, Vector3(1.3, 0.75, 0.8))
	K.part(rig.torso, K.box(Vector3(0.04, 0.22, 0.02)), trim, Vector3(0, 0.27, 0.13))
	# open-neck collar: skin upper chest, gold gorget edge
	K.part(rig.torso, K.cyl(0.075, 0.15, 0.08), skin, Vector3(0, 0.5, 0.0))
	K.part(rig.torso, K.torus(0.12, 0.155), trim, Vector3(0, 0.455, 0.0), Vector3(8, 0, 0), Vector3(1, 1, 0.8))
	# shoulders (exposed) and arms
	for arm in [rig.arm_l, rig.arm_r]:
		K.part(arm, K.sphere(0.06), skin, Vector3.ZERO)
		K.limb(arm, 0.048, 0.04, 0.3, skin)
		K.part(arm, K.cyl(0.048, 0.042, 0.26), armor, Vector3(0, -0.45, 0))
		K.part(arm, K.torus(0.04, 0.056), trim, Vector3(0, -0.33, 0))
		K.part(arm, K.sphere(0.042), skin, Vector3(0, -0.6, 0.0))
	# neck and head
	K.part(rig.head, K.cyl(0.04, 0.05, 0.12), skin, Vector3(0, -0.05, 0))
	K.part(rig.head, K.sphere(0.112), skin, Vector3(0, 0.08, 0.0), Vector3.ZERO, Vector3(0.92, 1.08, 1.0))
	K.part(rig.head, K.sphere(0.05), skin, Vector3(0, 0.02, 0.06), Vector3.ZERO, Vector3(1.1, 0.8, 0.9))
	var eye := K.mat(Color(0.1, 0.1, 0.12), 0.0, 0.2)
	if class_id == "hellbrand":
		eye = K.glow_mat(c.glow, 3.0)
	elif class_id == "starweaver":
		eye = K.glow_mat(Color(0.6, 0.95, 1.0), 1.4)
	for sx in [-1.0, 1.0]:
		K.part(rig.head, K.sphere(0.017), eye, Vector3(0.04 * sx, 0.095, 0.098), Vector3.ZERO, Vector3(1.3, 0.7, 0.5), false)
	K.part(rig.head, K.box(Vector3(0.035, 0.008, 0.01)), K.mat(Color(0.55, 0.2, 0.22), 0.0, 0.4), Vector3(0, 0.025, 0.108), Vector3.ZERO, Vector3.ONE, false)


static func _long_hair(rig: HumanoidRig, color: Color, length: float = 0.55, width: float = 0.24) -> void:
	var hair := K.mat(color, 0.05, 0.5, 0.1)
	K.part(rig.head, K.sphere(0.125), hair, Vector3(0, 0.12, -0.015), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	K.part(rig.head, K.box(Vector3(width, length, 0.07)), hair, Vector3(0, 0.08 - length * 0.5, -0.09), Vector3(-6, 0, 0))
	for sx in [-1.0, 1.0]:
		K.part(rig.head, K.box(Vector3(0.05, length * 0.75, 0.05)), hair, Vector3(0.105 * sx, 0.05 - length * 0.35, -0.01), Vector3(0, 0, -4 * sx))


static func _dawnwarden(rig: HumanoidRig, c: Dictionary) -> void:
	var gold := K.mat(Color("#d9b45a"), 0.25, 0.25, 1.0)
	var silver := K.mat(Color("#cfd2d8"), 0.0, 0.2, 1.0)
	_long_hair(rig, c.hair, 0.7, 0.26)
	# circlet + halo
	K.part(rig.head, K.torus(0.112, 0.128), gold, Vector3(0, 0.15, 0), Vector3(-8, 0, 0))
	K.part(rig.head, K.prism(Vector3(0.05, 0.08, 0.02)), K.glow_mat(c.glow, 2.5), Vector3(0, 0.2, 0.11))
	var halo := K.part(rig.head, K.torus(0.25, 0.27), K.glow_mat(c.glow, 3.0), Vector3(0, 0.22, -0.18), Vector3(90, 0, 0), Vector3.ONE, false)
	halo.name = "Halo"
	# winged pauldrons
	for sx in [-1.0, 1.0]:
		var arm := rig.arm_l if sx > 0 else rig.arm_r
		K.part(arm, K.sphere(0.085), silver, Vector3(0.01 * sx, 0.03, 0), Vector3.ZERO, Vector3(1.15, 0.8, 1.0))
		for j in 3:
			K.part(arm, K.prism(Vector3(0.05, 0.22 - j * 0.04, 0.015)), gold, Vector3(0.06 * sx, 0.1 + j * 0.03, -0.05 - j * 0.03), Vector3(-30 - j * 15, 0, -25 * sx))
	# cape (back)
	K.part(rig.torso, K.box(Vector3(0.36, 0.95, 0.02)), K.mat(Color("#1d2140"), 0.0, 0.8), Vector3(0, 0.0, -0.17), Vector3(8, 0, 0))
	K.part(rig.torso, K.box(Vector3(0.36, 0.03, 0.025)), gold, Vector3(0, 0.47, -0.16))
	# sword (right) and shield (left)
	var blade := K.glow_mat(Color("#fff2c4"), 1.6)
	K.part(rig.hand_r, K.box(Vector3(0.045, 0.95, 0.012)), blade, Vector3(0, -0.36, 0.36), Vector3(-45, 0, 0))
	K.part(rig.hand_r, K.box(Vector3(0.22, 0.03, 0.04)), gold, Vector3(0, -0.02, 0.02), Vector3(-45, 0, 0))
	K.part(rig.hand_r, K.cyl(0.018, 0.018, 0.14), K.mat(Color("#3b2a1e")), Vector3(0, 0.05, -0.05), Vector3(-45, 0, 0))
	var shield := K.pivot(rig.hand_l, "Shield", Vector3(0.06, 0.12, 0.0))
	K.part(shield, K.cyl(0.3, 0.3, 0.04, 20), silver, Vector3.ZERO, Vector3(0, 0, 90))
	K.part(shield, K.torus(0.27, 0.31), gold, Vector3.ZERO, Vector3(0, 0, 90))
	K.part(shield, K.sphere(0.08), K.glow_mat(c.glow, 2.0), Vector3(0.03, 0, 0), Vector3.ZERO, Vector3(0.4, 1, 1))
	for i in 8:
		K.part(shield, K.prism(Vector3(0.04, 0.1, 0.01)), gold, Vector3(0.025, 0, 0) + Vector3(0, cos(i * TAU / 8), sin(i * TAU / 8)) * 0.15, Vector3(i * 45, 0, 0) + Vector3(0, 90, 0))
	K.light(rig.head, c.glow, 0.6, 3.0, Vector3(0, 0.2, -0.2))


static func _hellbrand(rig: HumanoidRig, c: Dictionary) -> void:
	var horn := K.mat(Color("#1a1214"), 0.0, 0.3, 0.2)
	var ember := K.glow_mat(c.glow, 3.0)
	var steel := K.mat(Color("#41383c"), 0.0, 0.25, 0.9)
	_long_hair(rig, c.hair, 0.6, 0.22)
	# crimson streak in the hair
	K.part(rig.head, K.box(Vector3(0.03, 0.5, 0.075)), K.mat(Color("#9c1f22"), 0.4, 0.5), Vector3(0.06, -0.15, -0.095), Vector3(-6, 0, 0))
	# swept-back horns
	for sx in [-1.0, 1.0]:
		var h1 := K.part(rig.head, K.cyl(0.0, 0.03, 0.18, 8), horn, Vector3(0.06 * sx, 0.2, 0.0), Vector3(-55, 0, -20 * sx))
		K.part(h1, K.cyl(0.0, 0.012, 0.1, 8), K.mat(Color("#5b1b1b"), 0.6, 0.3), Vector3(0, 0.1, 0))
	# spiked shoulder guard (left), bare right shoulder
	K.part(rig.arm_l, K.sphere(0.08), steel, Vector3(0.01, 0.03, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	for j in 3:
		K.part(rig.arm_l, K.cyl(0.0, 0.022, 0.13, 6), steel, Vector3(0.05, 0.1, -0.04 + j * 0.04), Vector3(0, 0, -30))
	# belt with talismans and back loincloth
	K.part(rig.hips, K.torus(0.17, 0.2), K.mat(Color("#2a1a12"), 0.0, 0.6), Vector3(0, 0.07, 0))
	K.part(rig.hips, K.box(Vector3(0.22, 0.5, 0.02)), K.mat(Color("#4a1218"), 0.0, 0.8), Vector3(0, -0.3, -0.2), Vector3(10, 0, 0))
	for sx in [-1.0, 1.0]:
		K.part(rig.hips, K.sphere(0.025), ember, Vector3(0.17 * sx, 0.04, 0.08), Vector3.ZERO, Vector3.ONE, false)
	# dual curved blades
	for hand in [rig.hand_r, rig.hand_l]:
		K.part(hand, K.box(Vector3(0.035, 0.62, 0.012)), K.mat(Color("#2a2226"), 0.6, 0.2, 0.9, c.glow), Vector3(0, -0.24, 0.2), Vector3(-40, 0, 0))
		K.part(hand, K.box(Vector3(0.012, 0.6, 0.006)), ember, Vector3(0, -0.23, 0.215), Vector3(-40, 0, 0), Vector3(1, 1, 1), false)
		K.part(hand, K.cyl(0.016, 0.016, 0.12), K.mat(Color("#1a1012")), Vector3(0, 0, -0.03), Vector3(90, 0, 0))
	K.embers(rig.torso, c.glow, 10, Vector3(0.25, 0.4, 0.2), Vector3(0, 0.2, 0), 0.5)
	K.light(rig.torso, c.glow, 0.5, 2.5, Vector3(0, 0.2, 0.3))


static func _starweaver(rig: HumanoidRig, c: Dictionary) -> void:
	var wood := K.mat(Color("#5a3d27"), 0.0, 0.6)
	var leaf := K.mat(c.primary, 0.0, 0.6)
	var rune := K.glow_mat(c.glow, 2.4)
	# silver hair with long braid
	var hair := K.mat(c.hair, 0.08, 0.45, 0.1)
	K.part(rig.head, K.sphere(0.125), hair, Vector3(0, 0.12, -0.015), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	for i in 7:
		K.part(rig.head, K.sphere(0.045 - i * 0.003), hair, Vector3(0, 0.02 - i * 0.1, -0.13 - i * 0.012))
	# pointed ears
	for sx in [-1.0, 1.0]:
		K.part(rig.head, K.cyl(0.0, 0.025, 0.12, 6), K.mat(c.skin, 0.0, 0.55), Vector3(0.115 * sx, 0.1, -0.01), Vector3(0, 0, -70 * sx))
	# leaf diadem
	K.part(rig.head, K.torus(0.112, 0.124), leaf, Vector3(0, 0.15, 0), Vector3(-10, 0, 0))
	K.part(rig.head, K.sphere(0.02), rune, Vector3(0, 0.17, 0.115), Vector3.ZERO, Vector3.ONE, false)
	# short asymmetrical cloak + quiver
	K.part(rig.torso, K.box(Vector3(0.3, 0.55, 0.02)), K.mat(Color("#20332f"), 0.0, 0.8), Vector3(-0.04, 0.22, -0.16), Vector3(6, 0, 4))
	var quiver := K.part(rig.torso, K.cyl(0.05, 0.045, 0.45), wood, Vector3(0.1, 0.33, -0.15), Vector3(0, 0, -25))
	for i in 4:
		K.part(quiver, K.cyl(0.006, 0.006, 0.2), K.mat(Color("#ddd")), Vector3(-0.02 + i * 0.013, 0.28, 0))
	for sx in [-1.0, 1.0]:
		var arm := rig.arm_l if sx > 0 else rig.arm_r
		K.part(arm, K.prism(Vector3(0.12, 0.08, 0.1)), leaf, Vector3(0.0, 0.05, 0), Vector3(0, 0, -20 * sx))
	# bow in left hand: arc of segments + glowing string
	var bow := K.pivot(rig.hand_l, "Bow", Vector3(0.02, 0, 0.05))
	for i in 9:
		var a := deg_to_rad(-60 + i * 15)
		K.part(bow, K.box(Vector3(0.03, 0.15, 0.03)), wood, Vector3(0, sin(a) * 0.55, cos(a) * 0.18 - 0.1), Vector3(rad_to_deg(-a) * 0.5, 0, 0))
	K.part(bow, K.box(Vector3(0.006, 0.95, 0.006)), rune, Vector3(0, 0, -0.12), Vector3.ZERO, Vector3.ONE, false)
	K.embers(rig.torso, c.glow, 6, Vector3(0.2, 0.3, 0.2), Vector3(0, 0.3, 0), 0.3)
