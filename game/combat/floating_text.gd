class_name FloatingText
extends Label3D
## Pooled floating combat numbers.

const ELEMENT_COLORS := {
	"physical": Color(1, 1, 1), "light": Color(1.0, 0.9, 0.45), "fire": Color(1.0, 0.55, 0.2),
	"shadow": Color(0.75, 0.5, 1.0), "frost": Color(0.55, 0.9, 1.0), "arcane": Color(0.6, 0.8, 1.0),
}
const POOL_MAX := 48

static var _pool: Array = []
static var enabled := true

var _life := 0.0
var _vel := Vector3.ZERO


static func spawn(context: Node, pos: Vector3, amount: float, crit: bool, element: String, on_player: bool) -> void:
	if not enabled or context == null or not context.is_inside_tree():
		return
	var host: Node = WorldHost.get_host(context)
	if host == null:
		return
	var ft: FloatingText = null
	while not _pool.is_empty() and ft == null:
		var cand = _pool.pop_back()
		if is_instance_valid(cand):
			ft = cand
	if ft == null:
		ft = FloatingText.new()
		ft.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ft.no_depth_test = true
		ft.fixed_size = false
		ft.outline_size = 10
		ft.outline_modulate = Color(0, 0, 0, 0.85)
		ft.render_priority = 10
	if ft.get_parent() != host:
		if ft.get_parent():
			ft.get_parent().remove_child(ft)
		host.add_child(ft)
	ft.visible = true
	ft.text = ("%d!" % roundi(amount)) if crit else str(roundi(amount))
	ft.font_size = 64 if crit else 44
	ft.pixel_size = 0.009
	var c: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	if on_player:
		c = Color(1.0, 0.3, 0.3)
	elif crit:
		c = Color(1.0, 0.85, 0.2)
	ft.modulate = c
	ft.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.2, 0.2))
	ft._life = 0.9
	ft._vel = Vector3(randf_range(-0.6, 0.6), 3.2 if crit else 2.4, 0)
	ft.set_process(true)


func _process(delta: float) -> void:
	_life -= delta
	global_position += _vel * delta
	_vel.y -= 4.0 * delta
	modulate.a = clampf(_life / 0.4, 0.0, 1.0)
	if _life <= 0.0:
		visible = false
		set_process(false)
		if _pool.size() < POOL_MAX:
			_pool.append(self)
		else:
			queue_free()
