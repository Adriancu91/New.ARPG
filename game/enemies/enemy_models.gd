class_name EnemyModels
extends RefCounted
## PLACEHOLDER monster models from primitives (front = +Z). Each archetype has
## a distinct silhouette so enemies read instantly at ARPG camera distance.

const K = preload("res://game/characters/model_kit.gd")


static func build(enemy_id: String) -> Node3D:
	var e := DB.get_enemy(enemy_id)
	var base := Color(e.get("color", "#555555"))
	var glow := Color(e.get("glow", "#ff0000"))
	var root: Node3D
	match e.get("archetype", ""):
		"beast": root = _beast(base, glow)
		"ranged_caster": root = _cultist(base, glow)
		"assassin": root = _stalker(base, glow)
		"heavy": root = _colossus(base, glow)
		"boss": root = _bishop(base, glow)
		_: root = _sentinel(base, glow)
	root.scale = Vector3.ONE * float(e.get("scale", 1.0))
	return root


static func _sentinel(base: Color, glow: Color) -> Node3D:
	var rig := HumanoidRig.new()
	rig.build_skeleton(0.92, 0.24, 1.42, 0.12)
	rig.hunch = 0.25
	var plate := K.mat(base, 0.0, 0.45, 0.7)
	var rust := K.mat(Color("#4a3426"), 0.0, 0.8, 0.4)
	var cloth := K.mat(Color("#2a2430"), 0.0, 0.9)
	var g := K.glow_mat(glow, 3.0)
	for leg in [rig.leg_l, rig.leg_r]:
		K.limb(leg, 0.09, 0.075, 0.9, plate)
		K.part(leg, K.sphere(0.08), rust, Vector3(0, -0.45, 0.03))
	K.part(rig.hips, K.cyl(0.2, 0.28, 0.35), cloth, Vector3(0, -0.1, 0))
	K.part(rig.torso, K.cyl(0.26, 0.2, 0.55), plate, Vector3(0, 0.3, 0))
	K.part(rig.torso, K.box(Vector3(0.12, 0.2, 0.05)), rust, Vector3(0.06, 0.35, 0.2), Vector3(0, 0, 25))
	for arm in [rig.arm_l, rig.arm_r]:
		K.part(arm, K.sphere(0.12), plate, Vector3(0, 0.02, 0))
		K.limb(arm, 0.07, 0.06, 0.6, rust)
	K.part(rig.head, K.cyl(0.11, 0.13, 0.26), plate, Vector3(0, 0.08, 0))
	K.part(rig.head, K.box(Vector3(0.16, 0.025, 0.02)), g, Vector3(0, 0.1, 0.12), Vector3.ZERO, Vector3.ONE, false)
	K.part(rig.head, K.cyl(0.0, 0.03, 0.2, 6), rust, Vector3(0.05, 0.28, -0.02), Vector3(0, 0, -15))
	K.part(rig.hand_r, K.box(Vector3(0.06, 0.9, 0.015)), K.mat(Color("#5a4c44"), 0.0, 0.5, 0.8), Vector3(0, 0, 0.45), Vector3(90, 0, 0))
	K.part(rig.hand_l, K.box(Vector3(0.05, 0.5, 0.42)), rust, Vector3(0.05, 0.05, 0.05))
	return _wrap(rig)


static func _cultist(base: Color, glow: Color) -> Node3D:
	var rig := HumanoidRig.new()
	rig.build_skeleton(0.95, 0.19, 1.42, 0.09)
	rig.hunch = 0.1
	var robe := K.mat(base, 0.0, 0.95)
	var dark := K.mat(Color("#141012"), 0.0, 0.9)
	var g := K.glow_mat(glow, 3.5)
	K.part(rig.hips, K.cyl(0.18, 0.42, 1.0, 12), robe, Vector3(0, -0.45, 0))
	K.part(rig.torso, K.cyl(0.21, 0.18, 0.55), robe, Vector3(0, 0.27, 0))
	for arm in [rig.arm_l, rig.arm_r]:
		K.limb(arm, 0.07, 0.1, 0.55, robe)
		K.part(arm, K.sphere(0.06), g, Vector3(0, -0.6, 0), Vector3.ZERO, Vector3.ONE, false)
	K.part(rig.head, K.cyl(0.0, 0.17, 0.42, 10), robe, Vector3(0, 0.15, -0.02), Vector3(-12, 0, 0))
	K.part(rig.head, K.sphere(0.1), dark, Vector3(0, 0.05, 0.04))
	for sx in [-1.0, 1.0]:
		K.part(rig.head, K.sphere(0.018), g, Vector3(0.035 * sx, 0.07, 0.12), Vector3.ZERO, Vector3.ONE, false)
	K.part(rig.torso, K.torus(0.02, 0.035), K.mat(Color("#8a7a5a"), 0.0, 0.4, 0.8), Vector3(0, 0.4, 0.2))
	K.light(rig.torso, glow, 0.8, 3.0, Vector3(0, 0.1, 0.4))
	return _wrap(rig)


static func _stalker(base: Color, glow: Color) -> Node3D:
	var rig := HumanoidRig.new()
	rig.build_skeleton(1.0, 0.18, 1.5, 0.1)
	rig.hunch = 0.55
	rig.stride = 1.3
	var skin := K.mat(base, 0.0, 0.3, 0.2)
	var g := K.glow_mat(glow, 3.0)
	var shroud := K.mat(Color(0.05, 0.05, 0.08, 1.0), 0.0, 0.95)
	for leg in [rig.leg_l, rig.leg_r]:
		K.limb(leg, 0.06, 0.035, 1.0, skin)
	K.part(rig.torso, K.cyl(0.14, 0.08, 0.6), skin, Vector3(0, 0.3, 0))
	K.part(rig.torso, K.box(Vector3(0.5, 0.7, 0.02)), shroud, Vector3(0, 0.25, -0.12), Vector3(15, 0, 0))
	for arm in [rig.arm_l, rig.arm_r]:
		K.limb(arm, 0.045, 0.03, 0.75, skin)
		for j in 3:
			K.part(arm, K.cyl(0.0, 0.015, 0.3, 5), g, Vector3(-0.03 + j * 0.03, -0.9, 0.05), Vector3(20, 0, 0), Vector3.ONE, false)
	K.part(rig.head, K.sphere(0.1), skin, Vector3(0, 0.05, 0.05), Vector3.ZERO, Vector3(0.8, 0.9, 1.5))
	K.part(rig.head, K.box(Vector3(0.12, 0.02, 0.02)), g, Vector3(0, 0.07, 0.19), Vector3.ZERO, Vector3.ONE, false)
	for j in 4:
		K.part(rig.torso, K.cyl(0.0, 0.02, 0.15, 5), g, Vector3(0, 0.15 + j * 0.12, -0.1), Vector3(-60, 0, 0), Vector3.ONE, false)
	return _wrap(rig)


static func _colossus(base: Color, glow: Color) -> Node3D:
	var rig := HumanoidRig.new()
	rig.build_skeleton(0.8, 0.36, 1.4, 0.18)
	rig.hunch = 0.2
	rig.stride = 0.6
	rig.arm_swing = 0.3
	var stone := K.mat(base, 0.0, 0.9, 0.2)
	var lava := K.glow_mat(glow, 3.0)
	for leg in [rig.leg_l, rig.leg_r]:
		K.part(leg, K.box(Vector3(0.22, 0.8, 0.24)), stone, Vector3(0, -0.4, 0))
		K.part(leg, K.box(Vector3(0.24, 0.02, 0.26)), lava, Vector3(0, -0.35, 0), Vector3.ZERO, Vector3.ONE, false)
	K.part(rig.torso, K.box(Vector3(0.75, 0.75, 0.5)), stone, Vector3(0, 0.35, 0), Vector3(0, 0, 0))
	K.part(rig.torso, K.box(Vector3(0.3, 0.3, 0.02)), lava, Vector3(0, 0.38, 0.26), Vector3(0, 0, 45), Vector3.ONE, false)
	for arm in [rig.arm_l, rig.arm_r]:
		K.part(arm, K.box(Vector3(0.3, 0.3, 0.3)), stone, Vector3(0, 0.05, 0))
		K.part(arm, K.box(Vector3(0.2, 0.6, 0.2)), stone, Vector3(0, -0.35, 0))
		K.part(arm, K.box(Vector3(0.32, 0.3, 0.32)), stone, Vector3(0, -0.75, 0.02))
		K.part(arm, K.box(Vector3(0.34, 0.03, 0.34)), lava, Vector3(0, -0.62, 0.02), Vector3.ZERO, Vector3.ONE, false)
	K.part(rig.head, K.box(Vector3(0.22, 0.2, 0.22)), stone, Vector3(0, 0.0, 0.08))
	K.part(rig.head, K.box(Vector3(0.14, 0.03, 0.02)), lava, Vector3(0, 0.02, 0.2), Vector3.ZERO, Vector3.ONE, false)
	K.embers(rig.torso, glow, 8, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.6, 0), 0.4)
	K.light(rig.torso, glow, 1.0, 4.0, Vector3(0, 0.4, 0.5))
	return _wrap(rig)


static func _beast(base: Color, glow: Color) -> Node3D:
	var root := Node3D.new()
	var beast := BeastRig.new()
	root.add_child(beast)
	var fur := K.mat(base, 0.0, 0.95)
	var bone := K.mat(Color("#bdb5a0"), 0.0, 0.6)
	var g := K.glow_mat(glow, 3.0)
	beast.body = ModelKit.pivot(beast, "Body", Vector3(0, 0.6, 0))
	K.part(beast.body, K.capsule(0.24, 1.1), fur, Vector3.ZERO, Vector3(90, 0, 0))
	K.part(beast.body, K.sphere(0.28), fur, Vector3(0, 0.08, 0.35), Vector3.ZERO, Vector3(1, 1.1, 1))
	var head := ModelKit.pivot(beast.body, "Head", Vector3(0, 0.12, 0.6))
	K.part(head, K.box(Vector3(0.24, 0.22, 0.36)), fur, Vector3(0, 0, 0.1))
	K.part(head, K.box(Vector3(0.16, 0.08, 0.2)), bone, Vector3(0, -0.07, 0.3))
	for sx in [-1.0, 1.0]:
		K.part(head, K.sphere(0.03), g, Vector3(0.08 * sx, 0.05, 0.27), Vector3.ZERO, Vector3.ONE, false)
		K.part(head, K.cyl(0.0, 0.04, 0.16, 6), fur, Vector3(0.09 * sx, 0.16, 0.0), Vector3(-20, 0, -15 * sx))
		for j in 2:
			K.part(head, K.cyl(0.0, 0.012, 0.07, 5), bone, Vector3(0.05 * sx, -0.12, 0.33 + j * 0.03), Vector3(180, 0, 0))
	for j in 5:
		K.part(beast.body, K.cyl(0.0, 0.035, 0.18, 5), bone, Vector3(0, 0.22, 0.25 - j * 0.14), Vector3(-25, 0, 0))
	K.part(beast.body, K.cyl(0.02, 0.06, 0.5, 6), fur, Vector3(0, 0.05, -0.65), Vector3(-60, 0, 0))
	var legs_pos := [Vector3(0.15, 0, 0.35), Vector3(-0.15, 0, 0.35), Vector3(0.15, 0, -0.35), Vector3(-0.15, 0, -0.35)]
	for lp in legs_pos:
		var leg := ModelKit.pivot(beast.body, "Leg", lp + Vector3(0, -0.05, 0))
		K.limb(leg, 0.06, 0.04, 0.55, fur)
		beast.legs.append(leg)
	root.set_meta("rig", beast)
	return root


static func _bishop(base: Color, glow: Color) -> Node3D:
	var rig := HumanoidRig.new()
	rig.build_skeleton(1.0, 0.26, 1.55, 0.12)
	rig.hunch = 0.15
	rig.stride = 0.5
	var robe := K.mat(base, 0.0, 0.9)
	var gold := K.mat(Color("#8a6d3b"), 0.1, 0.3, 0.9)
	var bone := K.mat(Color("#cfc6b0"), 0.0, 0.6)
	var g := K.glow_mat(glow, 3.0)
	K.part(rig.hips, K.cyl(0.25, 0.55, 1.05, 16), robe, Vector3(0, -0.48, 0))
	for i in 8:
		var a := i * TAU / 8.0
		K.part(rig.hips, K.box(Vector3(0.12, 0.9, 0.02)), K.mat(Color("#3a1218"), 0.0, 0.9), Vector3(sin(a) * 0.45, -0.55, cos(a) * 0.45), Vector3(-8, rad_to_deg(a), 0))
	K.part(rig.torso, K.cyl(0.3, 0.24, 0.7), robe, Vector3(0, 0.33, 0))
	# exposed glowing ribcage
	for j in 4:
		K.part(rig.torso, K.torus(0.12 - j * 0.01, 0.14 - j * 0.01), bone, Vector3(0, 0.25 + j * 0.09, 0.2), Vector3(90, 0, 0), Vector3(1.2, 1, 0.5))
	K.part(rig.torso, K.sphere(0.08), g, Vector3(0, 0.35, 0.18), Vector3.ZERO, Vector3.ONE, false)
	# stole
	for sx in [-1.0, 1.0]:
		K.part(rig.torso, K.box(Vector3(0.1, 1.2, 0.02)), gold, Vector3(0.13 * sx, 0.05, 0.27), Vector3(-5, 0, 0))
	for arm in [rig.arm_l, rig.arm_r]:
		K.part(arm, K.sphere(0.14), gold, Vector3(0, 0.03, 0))
		K.limb(arm, 0.09, 0.15, 0.7, robe)
		K.part(arm, K.sphere(0.06), bone, Vector3(0, -0.72, 0))
	# skull face and towering mitre
	K.part(rig.head, K.sphere(0.13), bone, Vector3(0, 0.05, 0.03), Vector3.ZERO, Vector3(0.9, 1.1, 1.0))
	for sx in [-1.0, 1.0]:
		K.part(rig.head, K.sphere(0.025), g, Vector3(0.045 * sx, 0.08, 0.13), Vector3.ZERO, Vector3.ONE, false)
	K.part(rig.head, K.cyl(0.06, 0.15, 0.55, 4), K.mat(Color("#d8d0c0"), 0.0, 0.6), Vector3(0, 0.42, 0), Vector3(0, 45, 0))
	K.part(rig.head, K.box(Vector3(0.03, 0.5, 0.25)), gold, Vector3(0, 0.42, 0))
	# broken halo of spikes
	var halo := ModelKit.pivot(rig.head, "Halo", Vector3(0, 0.3, -0.25))
	for i in 10:
		var a := i * TAU / 10.0
		if i == 3 or i == 7:
			continue
		K.part(halo, K.cyl(0.0, 0.03, 0.3, 5), g, Vector3(sin(a), cos(a), 0) * 0.45, Vector3(0, 0, -rad_to_deg(a)), Vector3.ONE, false)
	# censer on chain (right hand) and crozier (left)
	var chain := ModelKit.pivot(rig.hand_r, "Censer", Vector3(0, -0.05, 0.05))
	K.part(chain, K.cyl(0.01, 0.01, 0.6), gold, Vector3(0, -0.3, 0))
	K.part(chain, K.sphere(0.16), gold, Vector3(0, -0.7, 0))
	K.part(chain, K.sphere(0.1), g, Vector3(0, -0.7, 0), Vector3.ZERO, Vector3(1.1, 1.1, 1.1), false)
	K.part(rig.hand_l, K.cyl(0.025, 0.025, 2.4), gold, Vector3(0, 0.3, 0.05))
	K.part(rig.hand_l, K.torus(0.12, 0.16), gold, Vector3(0, 1.55, 0.05), Vector3(90, 0, 90))
	K.embers(rig.torso, glow, 20, Vector3(0.5, 0.8, 0.5), Vector3(0, 0, 0), 0.7)
	K.light(rig.torso, glow, 2.0, 7.0, Vector3(0, 0.4, 0.6))
	return _wrap(rig)


static func _wrap(rig: Node3D) -> Node3D:
	var root := Node3D.new()
	root.add_child(rig)
	root.set_meta("rig", rig)
	return root
