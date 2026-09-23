extends CharacterBody3D
## 플레이어: 레인저 + 입체기동장치(ODM)
## - WASD 이동, Space 점프, Shift 가스 부스트
## - Q/E 좌/우 단독 훅, F 또는 우클릭 양쪽 훅, 재입력시 해제
## - 좌클릭/J 블레이드 공격, V 1인칭/3인칭 전환
## - 벽/건물/나무/거인 등 grappleable 그룹 + StaticBody 전부 그래플 가능
## - 모바일: TouchControls가 move_vec/look_delta/버튼 플래그를 주입

signal hp_changed(hp: float, max_hp: float)
signal gas_changed(gas: float, max_gas: float)
signal xp_changed(xp: float, need: float, level: int)
signal died
signal leveled_up(new_level: int)

const GRAVITY := 22.0
const WALK_SPEED := 7.0
const SPRINT_MULT := 1.6
const JUMP_VEL := 8.0
const HOOK_RANGE := 70.0
const HOOK_PULL := 34.0
const REEL_SPEED := 14.0
const GAS_MAX := 100.0

var max_hp := 100.0
var hp := 100.0
var gas := GAS_MAX
var attack_damage := 22.0
var attack_cooldown := 0.0
var level := 1
var xp := 0.0
var xp_need := 20.0
var move_speed_mult := 1.0
var hook_range_mult := 1.0
var crit_mult := 1.8

var yaw := 0.0
var pitch := -0.25
var first_person := false

var hook_l_point := Vector3.ZERO
var hook_r_point := Vector3.ZERO
var hook_l_node: Node3D = null
var hook_r_node: Node3D = null
var hook_l_offset := Vector3.ZERO
var hook_r_offset := Vector3.ZERO
var hook_l_on := false
var hook_r_on := false
var hook_l_len := 0.0
var hook_r_len := 0.0

# 모바일 주입
var mobile_move := Vector2.ZERO
var mobile_look := Vector2.ZERO
var mobile_gas := false
var mobile_attack := false
var mobile_jump := false

var _cam_pivot: Node3D
var _cam: Camera3D
var _fp_cam_pos: Node3D
var _body_root: Node3D
var _rope_l: MeshInstance3D
var _rope_r: MeshInstance3D
var _blade_l: MeshInstance3D
var _blade_r: MeshInstance3D
var _attack_fx := 0.0
var alive := true

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_build_visual()
	_build_camera()
	_build_ropes()
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("gas_changed", gas, GAS_MAX)

func _build_visual() -> void:
	_body_root = Node3D.new()
	add_child(_body_root)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	# 레인저 에셋 시도, 실패시 캡슐 폴백
	var ranger_path := "res://assets/characters/ranger/Exports/glTF (Godot-Unreal)/Outfits/Male_Ranger.gltf"
	var loaded := false
	if ResourceLoader.exists(ranger_path):
		var scene: PackedScene = load(ranger_path)
		if scene != null:
			var inst: Node3D = scene.instantiate()
			inst.scale = Vector3.ONE * 1.0
			_body_root.add_child(inst)
			loaded = true
	if not loaded:
		var bm := CapsuleMesh.new()
		bm.radius = 0.35
		bm.height = 1.6
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.position.y = 0.9
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.45, 0.25)
		mi.material_override = mat
		_body_root.add_child(mi)
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		head.mesh = sm
		head.position.y = 1.85
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.9, 0.75, 0.6)
		head.material_override = hmat
		_body_root.add_child(head)
	# 블레이드 2자루 (원시 박스, Medieval Weapons 대체 가능 구조)
	for side in [-1.0, 1.0]:
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.06, 1.1)
		blade.mesh = box
		blade.position = Vector3(0.45 * side, 1.1, -0.3)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.85, 0.9)
		m.metallic = 0.8
		m.roughness = 0.25
		blade.material_override = m
		_body_root.add_child(blade)
		if side < 0.0:
			_blade_l = blade
		else:
			_blade_r = blade

func _build_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.position = Vector3(0, 1.6, 0)
	add_child(_cam_pivot)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.current = true
	_cam.position = Vector3(0, 0.6, 4.2)
	_cam_pivot.add_child(_cam)
	_fp_cam_pos = Node3D.new()
	_fp_cam_pos.position = Vector3(0, 0.15, 0.2)
	_cam_pivot.add_child(_fp_cam_pos)

func _build_ropes() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [0, 1]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = 1.0
		mi.mesh = cyl
		mi.material_override = mat
		mi.visible = false
		mi.top_level = true
		get_parent().call_deferred("add_child", mi)
		if side == 0:
			_rope_l = mi
		else:
			_rope_r = mi

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var s: float = Settings.mouse_factor()
		yaw -= mm.relative.x * s
		pitch = clampf(pitch - mm.relative.y * s, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	# --- 입력 ---
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_move.length() > 0.05:
		iv = mobile_move
	if mobile_look.length() > 0.001:
		yaw -= mobile_look.x * 0.08 * Settings.mouse_sensitivity
		pitch = clampf(pitch - mobile_look.y * 0.08 * Settings.mouse_sensitivity, -1.35, 1.35)
		mobile_look = Vector2.ZERO
	rotation.y = yaw
	_cam_pivot.rotation.x = pitch
	_update_view_mode()
	# --- 이동 ---
	var basis_y := Basis(Vector3.UP, yaw)
	var wish := Vector3(iv.x, 0, iv.y)
	# Input.get_vector: y가 back-forward이므로 -z가 forward
	wish = basis_y * Vector3(iv.x, 0.0, iv.y)
	var sprinting := Input.is_action_pressed("gas_boost") or mobile_gas
	var speed := WALK_SPEED * move_speed_mult * (SPRINT_MULT if sprinting else 1.0)
	if sprinting and gas > 0.0 and wish.length() > 0.1:
		gas = maxf(0.0, gas - 12.0 * delta)
	var hv := Vector3(velocity.x, 0, velocity.z)
	var target := wish.normalized() * speed if wish.length() > 0.05 else Vector3.ZERO
	hv = hv.lerp(target, 1.0 - exp(-10.0 * delta))
	velocity.x = hv.x
	velocity.z = hv.z
	# --- 중력/점프 ---
	var on_floor := is_on_floor()
	if on_floor and gas < GAS_MAX:
		gas = minf(GAS_MAX, gas + 18.0 * delta)
	if not on_floor:
		velocity.y -= GRAVITY * delta
	var want_jump := Input.is_action_just_pressed("jump") or mobile_jump
	mobile_jump = false
	if want_jump and on_floor:
		velocity.y = JUMP_VEL
	# --- 훅 입력 ---
	if Input.is_action_just_pressed("hook_left"):
		_toggle_hook(true)
	if Input.is_action_just_pressed("hook_right"):
		_toggle_hook(false)
	if Input.is_action_just_pressed("hook_both"):
		if hook_l_on or hook_r_on:
			_release_hooks()
		else:
			_fire_hook(true)
			_fire_hook(false)
	if Input.is_action_just_pressed("toggle_view"):
		first_person = not first_person
	if Input.is_action_just_pressed("attack") or mobile_attack:
		mobile_attack = false
		_try_attack()
	# --- 훅 물리 ---
	_apply_hooks(delta)
	move_and_slide()
	_update_ropes()
	_update_blade_fx(delta)
	emit_signal("gas_changed", gas, GAS_MAX)

func _update_view_mode() -> void:
	if first_person:
		_cam.position = _cam.position.lerp(Vector3(0, 0.15, 0.25), 0.2)
		_body_root.visible = false
	else:
		_cam.position = _cam.position.lerp(Vector3(0, 0.6, 4.2), 0.2)
		_body_root.visible = true

func _toggle_hook(left: bool) -> void:
	var on: bool = hook_l_on if left else hook_r_on
	if on:
		if left:
			hook_l_on = false
			if is_instance_valid(_rope_l):
				_rope_l.visible = false
		else:
			hook_r_on = false
			if is_instance_valid(_rope_r):
				_rope_r.visible = false
	else:
		_fire_hook(left)

func _fire_hook(left: bool) -> void:
	var from := _cam.global_position
	var dir := -_cam.global_transform.basis.z
	var range_m := HOOK_RANGE * hook_range_mult
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * range_m)
	query.collide_with_areas = false
	query.collision_mask = 1 | 4 # 월드(1) + 거인(4)
	var space := get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	var pos: Vector3 = hit["position"]
	var collider: Object = hit["collider"]
	var node := collider as Node3D
	# 거인/움직이는 물체면 추적용 노드 저장
	var track: Node3D = null
	var off := Vector3.ZERO
	if node != null and (node.is_in_group("titan") or node.is_in_group("grapple_moving")):
		track = node
		off = pos - node.global_position
	if left:
		hook_l_on = true
		hook_l_point = pos
		hook_l_node = track
		hook_l_offset = off
		hook_l_len = global_position.distance_to(pos)
	else:
		hook_r_on = true
		hook_r_point = pos
		hook_r_node = track
		hook_r_offset = off
		hook_r_len = global_position.distance_to(pos)

func _release_hooks() -> void:
	hook_l_on = false
	hook_r_on = false
	if is_instance_valid(_rope_l):
		_rope_l.visible = false
	if is_instance_valid(_rope_r):
		_rope_r.visible = false

func _current_anchor(left: bool) -> Vector3:
	if left:
		if is_instance_valid(hook_l_node):
			return hook_l_node.global_position + hook_l_offset
		return hook_l_point
	else:
		if is_instance_valid(hook_r_node):
			return hook_r_node.global_position + hook_r_offset
		return hook_r_point

func _apply_hooks(delta: float) -> void:
	var hooked := 0
	if hook_l_on:
		hooked += 1
	if hook_r_on:
		hooked += 1
	if hooked == 0:
		return
	var boosting := Input.is_action_pressed("gas_boost") or mobile_gas
	for left in [true, false]:
		var on: bool = hook_l_on if left else hook_r_on
		if not on:
			continue
		var anchor := _current_anchor(left)
		if left:
			if is_instance_valid(hook_l_node):
				hook_l_point = anchor
			else:
				hook_l_point = anchor
		else:
			if is_instance_valid(hook_r_node):
				hook_r_point = anchor
			else:
				hook_r_point = anchor
		var to: Vector3 = anchor - global_position
		var dist := to.length()
		if dist < 2.5:
			if left:
				hook_l_on = false
			else:
				hook_r_on = false
			continue
		var dir := to / dist
		# 릴 감기: 가스 소모하며 유효 길이 단축
		if boosting and gas > 0.5:
			gas = maxf(0.0, gas - 16.0 * delta)
			if left:
				hook_l_len = maxf(3.0, hook_l_len - REEL_SPEED * delta)
			else:
				hook_r_len = maxf(3.0, hook_r_len - REEL_SPEED * delta)
		var rest: float = hook_l_len if left else hook_r_len
		if dist > rest:
			var excess := dist - rest
			# 스프링 당김 + 댐핑
			velocity += dir * (HOOK_PULL * delta * (1.0 + excess * 0.15))
			# 줄 방향 속도 유지, 반대 감쇠
			var along: float = velocity.dot(dir)
			if along < 0.0:
				velocity -= dir * along * 0.4 * delta * 10.0 * 0.1
		# 공중 부양 보조: 줄이 위를 향하면 중력 일부 상쇄
		if dir.y > 0.25:
			velocity.y += GRAVITY * 0.55 * delta

func _update_ropes() -> void:
	_draw_rope(_rope_l, hook_l_on, true)
	_draw_rope(_rope_r, hook_r_on, false)

func _draw_rope(mi: MeshInstance3D, on: bool, left: bool) -> void:
	if not is_instance_valid(mi):
		return
	if not on:
		mi.visible = false
		return
	mi.visible = true
	var anchor := _current_anchor(left)
	var start := global_position + Vector3(0, 1.3, 0)
	var mid := (start + anchor) * 0.5
	var d := start.distance_to(anchor)
	mi.global_position = mid
	mi.scale = Vector3(1, 1, 1)
	# 실린더 Y축을 방향에 맞춤
	var up := (anchor - start).normalized()
	if up.length() < 0.01:
		mi.visible = false
		return
	mi.global_transform = Transform3D(Basis(), mid)
	var y_axis := up
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length() < 0.05:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	mi.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis).scaled(Vector3(1, d, 1)), mid)

func _try_attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.45
	_attack_fx = 0.18
	var origin := global_position
	var fwd := -global_transform.basis.z
	var air_bonus := 1.0 if is_on_floor() else 1.35
	var hook_bonus := 1.5 if (hook_l_on or hook_r_on) else 1.0
	var dmg := attack_damage * air_bonus * hook_bonus
	var crit := hook_bonus > 1.0 and not is_on_floor()
	if crit:
		dmg *= crit_mult
	for t in get_tree().get_nodes_in_group("titan"):
		var titan := t as Node3D
		if titan == null:
			continue
		var to: Vector3 = titan.global_position - origin
		to.y = 0.0
		var dist := to.length()
		var reach := 4.5 + (titan as CharacterBody3D).scale.x * 1.2
		if dist > reach:
			continue
		var ang := rad_to_deg(acos(clampf(fwd.normalized().dot(to.normalized()), -1.0, 1.0))) if to.length() > 0.01 else 0.0
		if ang < 70.0:
			if titan.has_method("take_damage"):
				titan.take_damage(dmg, global_position, crit)

func _update_blade_fx(delta: float) -> void:
	if _attack_fx > 0.0:
		_attack_fx -= delta
		var k := 1.0 - maxf(_attack_fx, 0.0) / 0.18
		if is_instance_valid(_blade_l):
			_blade_l.rotation.x = lerp(0.0, -1.2, k)
		if is_instance_valid(_blade_r):
			_blade_r.rotation.x = lerp(0.0, -1.2, k)
	else:
		if is_instance_valid(_blade_l):
			_blade_l.rotation.x = lerpf(_blade_l.rotation.x, 0.0, 0.2)
		if is_instance_valid(_blade_r):
			_blade_r.rotation.x = lerpf(_blade_r.rotation.x, 0.0, 0.2)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - amount)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0.0:
		alive = false
		_release_hooks()
		emit_signal("died")

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	emit_signal("hp_changed", hp, max_hp)

func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = 20.0 * pow(1.35, level - 1)
		emit_signal("leveled_up", level)
	emit_signal("xp_changed", xp, xp_need, level)

func apply_upgrade(kind: String) -> void:
	match kind:
		"damage":
			attack_damage *= 1.25
		"hp":
			max_hp += 25.0
			heal(25.0)
		"speed":
			move_speed_mult += 0.12
		"gas":
			# 가스통 확장: 현재 스크립트 상수 대신 회복/소모 효율로 체감
			move_speed_mult += 0.03
			attack_damage += 2.0
		"range":
			hook_range_mult += 0.2
		"crit":
			crit_mult += 0.25
