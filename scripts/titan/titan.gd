extends CharacterBody3D
## 거인(몬스터): Universal Base Characters 남성 베이스를 스케일로 5단계 거인화
## 티어: 0 소형 / 1 소중형 / 2 중형 / 3 중대형 / 4 대형

signal killed(titan: Node3D, tier: int, xp_value: float)

const TIER_NAMES := ["소형", "소중형", "중형", "중대형", "대형"]
const TIER_SCALE := [1.5, 2.1, 3.0, 4.2, 5.8]
const TIER_HP := [30.0, 65.0, 130.0, 230.0, 420.0]
const TIER_DMG := [8.0, 14.0, 24.0, 38.0, 60.0]
const TIER_SPEED := [3.2, 3.0, 3.6, 4.0, 4.6]
const TIER_XP := [5.0, 8.0, 14.0, 22.0, 40.0]

var tier := 0
var hp := 30.0
var max_hp := 30.0
var damage := 10.0
var speed := 3.0
var xp_value := 5.0
var attack_range := 3.0
var attack_cooldown := 0.0
var _windup := 0.0
var _player: Node3D = null
var _visual: Node3D
var _flash := 0.0
var _separation := Vector3.ZERO

func setup(p_tier: int, player: Node3D) -> void:
	tier = clampi(p_tier, 0, 4)
	hp = TIER_HP[tier]
	max_hp = hp
	damage = TIER_DMG[tier]
	speed = TIER_SPEED[tier]
	xp_value = TIER_XP[tier]
	_player = player
	var s: float = TIER_SCALE[tier]
	scale = Vector3.ONE * s
	attack_range = 2.4 * s

func _ready() -> void:
	add_to_group("titan")
	add_to_group("grappleable") # 입체기동 그래플 가능
	add_to_group("grapple_moving")
	collision_layer = 4
	collision_mask = 1 | 2
	_build_visual()
	_build_collision()

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	add_child(col)

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var path := "res://assets/characters/titan/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf"
	var ok := false
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		if ps != null:
			var inst: Node3D = ps.instantiate()
			_visual.add_child(inst)
			ok = true
			# 티어별 피부톤: 대형일수록 창백+붉은 눈 느낌 (머티리얼 오버라이드는 하위 메시 순회)
			_tint_recursive(inst, tier)
	if not ok:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.45
		cap.height = 1.8
		body.mesh = cap
		body.position.y = 1.0
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.8, 0.7).lerp(Color(0.75, 0.6, 0.55), tier / 4.0)
		body.material_override = m
		_visual.add_child(body)
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.56
		head.mesh = sm
		head.position.y = 2.1
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.95, 0.82, 0.72)
		head.material_override = hm
		_visual.add_child(head)

func _tint_recursive(n: Node, p_tier: int) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.93, 0.8, 0.7).lerp(Color(0.7, 0.55, 0.5), p_tier / 4.0)
		m.roughness = 0.8
		mi.material_override = m
	for c in n.get_children():
		_tint_recursive(c, p_tier)

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	if not is_instance_valid(_player):
		var ps := get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			_player = ps[0]
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return
	var to: Vector3 = _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	# 분리(뭉침 방지)
	_separation = _separation.lerp(Vector3.ZERO, delta * 2.0)
	if _windup > 0.0:
		_windup -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _windup <= 0.0:
			# 타격 판정
			var d2: float = global_position.distance_to(_player.global_position)
			if d2 < attack_range * 1.2 and _player.has_method("take_damage"):
				_player.take_damage(damage)
	else:
		if dist < attack_range and attack_cooldown <= 0.0:
			_windup = 0.55
			attack_cooldown = 1.9
		else:
			var v: Vector3 = (dir * speed) + _separation
			velocity.x = v.x
			velocity.z = v.z
			if dir.length() > 0.01:
				var target_yaw := atan2(-dir.x, -dir.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 4.0))
	move_and_slide()
	# 피격 플래시 스케일 펀치
	if _flash > 0.0 and is_instance_valid(_visual):
		var k := 1.0 + _flash * 1.5
		_visual.scale = Vector3.ONE * k
	else:
		if is_instance_valid(_visual):
			_visual.scale = _visual.scale.lerp(Vector3.ONE, minf(1.0, delta * 10.0))

func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO, crit: bool = false) -> void:
	hp -= amount
	_flash = 0.12
	if hp <= 0.0:
		die()

func add_separation(push: Vector3) -> void:
	_separation += push

func die() -> void:
	emit_signal("killed", self, tier, xp_value)
	_spawn_xp_gem()
	queue_free()

func _spawn_xp_gem() -> void:
	var gem := Area3D.new()
	gem.set_meta("xp", xp_value)
	get_parent().add_child(gem)
	gem.global_position = global_position + Vector3(0, 1.5 * scale.x, 0)
	gem.collision_layer = 8
	gem.collision_mask = 2
	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.2
	col.shape = sp
	gem.add_child(col)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 1.0, 0.4)
	m.emission_enabled = true
	m.emission = Color(0.2, 1.0, 0.3)
	mi.material_override = m
	gem.add_child(mi)
	var script := load("res://scripts/titan/xp_gem.gd")
	gem.set_script(script)
