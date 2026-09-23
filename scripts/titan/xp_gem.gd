extends Area3D
## 처치시 드롭되는 XP 젬: 플레이어에게 자석처럼 끌려가고 획득시 xp 지급.

var xp := 5.0
var _t := 0.0

func _ready() -> void:
	if has_meta("xp"):
		xp = float(get_meta("xp"))
	body_entered.connect(_on_body)
	_t = randf() * 10.0

func _physics_process(delta: float) -> void:
	_t += delta
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p := ps[0] as Node3D
	if p == null or not p.has_method("gain_xp"):
		return
	var d: float = global_position.distance_to(p.global_position)
	var magnet_r := 7.0
	if d < magnet_r:
		var dir: Vector3 = (p.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
		var spd := lerpf(18.0, 6.0, clampf(d / magnet_r, 0.0, 1.0))
		global_position += dir * spd * delta
	rotation.y += delta * 3.0
	position.y += sin(_t * 4.0) * delta * 0.5

func _on_body(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("gain_xp"):
		body.gain_xp(xp)
		if body.has_method("heal"):
			pass
		queue_free()
