extends Node3D
## 아레나(진격의 거인식 벽+마을) 프로시저럴 생성
## - 참조: 원작의 3중 벽(마리아/로제/시나) + 중앙 마을 + 외곽 거대수림
## - Medieval Village MegaKit 다량 사용: 벽/지붕/문/창문/소품 모듈
## - Stylized Nature MegaKit: 나무(Common/Pine/Twisted) + 바닥(잔디/바위)
## - 모든 벽/건물/나무는 grappleable 그룹 → 입체기동 그래플 가능
## - 에셋 로드 실패시 원시 메시 폴백으로 게임 보장

const ARENA_HALF := 100.0
const INNER_HALF := 55.0
const WALL_H := 12.0

var _rng := RandomNumberGenerator.new()

# 마을 모듈 curated 목록 (존재하는 것만 사용, 없으면 스킵→폴백)
const WALL_PIECES := [
	"Wall_Plaster_Straight", "Wall_Plaster_Straight_Base",
	"Wall_UnevenBrick_Straight", "Wall_Plaster_Door_Flat",
	"Wall_UnevenBrick_Door_Flat", "Wall_Plaster_Window_Wide_Flat",
	"Wall_UnevenBrick_Window_Wide_Flat", "Wall_Plaster_WoodGrid",
]
const ROOF_PIECES := [
	"Roof_RoundTiles_6x6", "Roof_RoundTiles_6x8", "Roof_RoundTiles_4x6",
	"Roof_Wooden_2x1_Middle", "Roof_Tower_RoundTiles", "Roof_Dormer_RoundTile",
]
const PROP_PIECES := [
	"Prop_Crate", "Prop_Wagon", "Prop_Chimney", "Prop_WoodenFence_Single",
	"Prop_MetalFence_Simple", "Prop_Vine1", "Prop_Vine2",
]
const TREE_GLTFS := [
	"CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5",
	"Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5",
	"TwistedTree_1", "TwistedTree_2", "TwistedTree_3",
	"DeadTree_1", "DeadTree_3",
]
const BUSH_ROCK := ["Bush_Common", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]

func build(mobile_mode: bool = false) -> void:
	_rng.seed = 20260923
	_build_lights()
	_build_ground()
	_build_outer_walls()
	_build_inner_walls()
	_build_village(mobile_mode)
	_build_forest(mobile_mode)
	_build_props()

func _village_gltf(name: String) -> String:
	return "res://assets/village/glTF/%s.gltf" % name

func _nature_gltf(name: String) -> String:
	return "res://assets/nature/%s.gltf" % name

func _try_instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	return n

func _add_static(n: Node3D, pos: Vector3, yaw: float = 0.0, scl: float = 1.0, grapple: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	body.scale = Vector3.ONE * scl
	if grapple:
		body.add_to_group("grappleable")
	add_child(body)
	body.add_child(n)
	n.position = Vector3.ZERO
	# 자동 콜리전: AABB 기반 박스 생성
	var aabb := AABB(Vector3(-1, 0, -1), Vector3(2, 3, 2))
	var probe := _find_first_mesh(n)
	if probe != null:
		aabb = probe.get_aabb()
		# 스케일 반영 전 로컬 기준이므로 그대로 사용
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(aabb.size.x, 0.5), maxf(aabb.size.y, 0.5), maxf(aabb.size.z, 0.5))
	col.shape = box
	col.position = aabb.get_center()
	body.add_child(col)
	return body

func _find_first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_first_mesh(c)
		if r != null:
			return r
	return null

func _fallback_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	return mi

func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-30), 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.35, 0.55, 0.85)
	psm.sky_horizon_color = Color(0.75, 0.82, 0.9)
	psm.ground_bottom_color = Color(0.3, 0.35, 0.3)
	psm.ground_horizon_color = Color(0.65, 0.7, 0.65)
	psm.sun_angle_max = 30.0
	sky.sky_material = psm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.75, 0.8, 0.85)
	e.fog_density = 0.004
	env.environment = e
	add_child(env)

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("grappleable") # 바닥은 그래플 제외? 원작 고정은 불가 → 제외. 그래도 그룹 미포함
	body.remove_from_group("grappleable")
	add_child(body)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA_HALF * 2.0 + 60.0, ARENA_HALF * 2.0 + 60.0)
	pm.subdivide_width = 32
	pm.subdivide_depth = 32
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.48, 0.28)
	m.roughness = 1.0
	mi.material_override = m
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var ws := WorldBoundaryShape3D.new()
	col.shape = ws
	body.add_child(col)
	# 중앙 광장 (석재 원판)
	var plaza := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 14.0
	cyl.bottom_radius = 14.0
	cyl.height = 0.15
	plaza.mesh = cyl
	plaza.position = Vector3(0, 0.07, 0)
	var pm2 := StandardMaterial3D.new()
	pm2.albedo_color = Color(0.55, 0.52, 0.48)
	plaza.material_override = pm2
	add_child(plaza)

func _wall_box(length: float, height: float, thick: float, pos: Vector3, brick: bool = true) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("grappleable") # 벽 그래플 핵심
	body.position = pos
	add_child(body)
	var mi := _fallback_box(Vector3(length, height, thick), Color(0.72, 0.68, 0.6) if brick else Color(0.6, 0.58, 0.52))
	mi.position = Vector3(0, height * 0.5, 0)
	body.add_child(mi)
	# 윗면 돌출부(원작 벽 상부)
	var trim := _fallback_box(Vector3(length, 0.6, thick + 0.8), Color(0.55, 0.52, 0.47))
	trim.position = Vector3(0, height + 0.3, 0)
	body.add_child(trim)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, height + 0.6, thick + 0.8)
	col.shape = box
	col.position = Vector3(0, (height + 0.6) * 0.5, 0)
	body.add_child(col)

func _build_outer_walls() -> void:
	var h := ARENA_HALF
	_wall_box(h * 2.0, WALL_H, 3.0, Vector3(0, 0, -h))
	_wall_box(h * 2.0, WALL_H, 3.0, Vector3(0, 0, h))
	_wall_box(h * 2.0, WALL_H, 3.0, Vector3(-h, 0, 0), true)
	var b := get_children().back() as StaticBody3D
	b.rotation.y = PI * 0.5
	_wall_box(h * 2.0, WALL_H, 3.0, Vector3(h, 0, 0), true)
	var b2 := get_children().back() as StaticBody3D
	b2.rotation.y = PI * 0.5
	# 모서리 망루 4개
	for x in [-h, h]:
		for z in [-h, h]:
			var tower := _fallback_box(Vector3(7, WALL_H + 5.0, 7), Color(0.62, 0.58, 0.52))
			_add_static(tower, Vector3(x, 0, z))

func _build_inner_walls() -> void:
	# 제2벽(로제): 중앙 마을을 감싸는 사각 링, 4면에 문(간격 10m)
	var h := INNER_HALF
	var seg := 24.0
	for side in 4:
		for i in [-2, -1, 1, 2]:
			var off := float(i) * (seg * 0.5 + 1.0)
			if side == 0:
				_wall_box(seg, 10.0, 2.5, Vector3(off, 0, -h))
			elif side == 1:
				_wall_box(seg, 10.0, 2.5, Vector3(off, 0, h))
			elif side == 2:
				_wall_box(seg, 10.0, 2.5, Vector3(-h, 0, off))
				(get_children().back() as StaticBody3D).rotation.y = PI * 0.5
			else:
				_wall_box(seg, 10.0, 2.5, Vector3(h, 0, off))
				(get_children().back() as StaticBody3D).rotation.y = PI * 0.5

func _build_village(mobile: bool) -> void:
	# 격자 마을: 중앙 제외, 블록마다 집 1~2채 (모듈 3피스 조합)
	var step := 22.0
	var count := 0
	var max_houses := 26 if not mobile else 14
	for gx in range(-3, 4):
		for gz in range(-3, 4):
			if count >= max_houses:
				break
			var bx := float(gx) * step + _rng.randf_range(-3.0, 3.0)
			var bz := float(gz) * step + _rng.randf_range(-3.0, 3.0)
			if Vector2(bx, bz).length() < 18.0:
				continue # 중앙 광장 비움
			if absf(bx) > ARENA_HALF - 12.0 or absf(bz) > ARENA_HALF - 12.0:
				continue
			# 내벽선과 겹치면 스킵
			if absf(absf(bx) - INNER_HALF) < 6.0 or absf(absf(bz) - INNER_HALF) < 6.0:
				if randf() < 0.7:
					continue
			_build_house(Vector3(bx, 0, bz), _rng.randf() * TAU)
			count += 1
	# 가로등/울타리 라인
	for i in range(-4, 5):
		_add_prop("Prop_WoodenFence_Single", Vector3(float(i) * 8.0, 0, 20.0), 0.0)
		_add_prop("Prop_WoodenFence_Single", Vector3(float(i) * 8.0, 0, -20.0), 0.0)

func _build_house(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var wname: String = WALL_PIECES[_rng.randi() % WALL_PIECES.size()]
	var rname: String = ROOF_PIECES[_rng.randi() % ROOF_PIECES.size()]
	var w := _try_instance(_village_gltf(wname))
	if w == null:
		w = _fallback_box(Vector3(6, 3.5, 6), Color(0.8, 0.75, 0.65))
	var wall_body := StaticBody3D.new()
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	wall_body.add_to_group("grappleable")
	root.add_child(wall_body)
	wall_body.add_child(w)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3.5, 6)
	col.shape = box
	col.position = Vector3(0, 1.75, 0)
	wall_body.add_child(col)
	# 지붕
	var r := _try_instance(_village_gltf(rname))
	if r == null:
		r = _fallback_box(Vector3(7, 1.2, 7), Color(0.55, 0.3, 0.25))
	r.position = Vector3(0, 3.6, 0)
	var roof_body := StaticBody3D.new()
	roof_body.collision_layer = 1
	roof_body.collision_mask = 0
	roof_body.add_to_group("grappleable")
	root.add_child(roof_body)
	roof_body.add_child(r)
	var col2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(7, 1.2, 7)
	col2.shape = box2
	col2.position = Vector3(0, 3.6, 0)
	roof_body.add_child(col2)
	# 굴뚝/상자 prop 0~2개
	if _rng.randf() < 0.6:
		_add_prop_at(root, "Prop_Chimney", Vector3(1.5, 4.5, 1.0))
	if _rng.randf() < 0.5:
		_add_prop_at(root, "Prop_Crate", Vector3(_rng.randf_range(-4.0, 4.0), 0.4, _rng.randf_range(-4.0, 4.0)))

func _add_prop(gltf_base: String, pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	_add_prop_at(root, gltf_base, Vector3.ZERO)

func _add_prop_at(root: Node3D, gltf_base: String, local: Vector3) -> void:
	var inst := _try_instance(_village_gltf(gltf_base))
	if inst == null:
		inst = _fallback_box(Vector3(1, 1, 1), Color(0.5, 0.4, 0.3))
	inst.position = local
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("grappleable")
	root.add_child(body)
	body.add_child(inst)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	col.shape = box
	col.position = local
	body.add_child(col)

func _build_forest(mobile: bool) -> void:
	# 외곽 거대수림(원작) + 마을 사이 산책로 수목
	var n_outer := 70 if not mobile else 36
	for i in n_outer:
		var ang := _rng.randf() * TAU
		var rad := _rng.randf_range(ARENA_HALF + 8.0, ARENA_HALF + 26.0)
		var pos := Vector3(cos(ang) * rad, 0, sin(ang) * rad)
		_spawn_tree(pos, _rng.randf_range(1.2, 1.8))
	var n_inner := 26 if not mobile else 14
	for i in n_inner:
		var pos := Vector3(_rng.randf_range(-85.0, 85.0), 0, _rng.randf_range(-85.0, 85.0))
		if Vector2(pos.x, pos.z).length() < 20.0:
			continue
		_spawn_tree(pos, _rng.randf_range(0.9, 1.4))
	# 덤불/바위
	for i in (30 if not mobile else 16):
		var bname: String = BUSH_ROCK[_rng.randi() % BUSH_ROCK.size()]
		var pos := Vector3(_rng.randf_range(-90.0, 90.0), 0, _rng.randf_range(-90.0, 90.0))
		var inst := _try_instance(_nature_gltf(bname))
		if inst == null:
			inst = _fallback_box(Vector3(1, 0.8, 1), Color(0.3, 0.45, 0.3))
		_add_static(inst, pos, _rng.randf() * TAU, _rng.randf_range(0.8, 1.5))

func _spawn_tree(pos: Vector3, scl: float) -> void:
	var tname: String = TREE_GLTFS[_rng.randi() % TREE_GLTFS.size()]
	var inst := _try_instance(_nature_gltf(tname))
	if inst == null:
		# 폴백: 기둥+수관
		var root := Node3D.new()
		var trunk := _fallback_box(Vector3(0.8, 6.0, 0.8), Color(0.35, 0.25, 0.18))
		trunk.position.y = 3.0
		root.add_child(trunk)
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.2
		sm.height = 4.4
		crown.mesh = sm
		crown.position.y = 7.0
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.5, 0.25)
		crown.material_override = m
		root.add_child(crown)
		inst = root
	# 나무는 키가 크므로 스케일 업 → 그래플 앵커로 최적
	_add_static(inst, pos, _rng.randf() * TAU, scl * 1.6)

func _build_props() -> void:
	# 마차/상자 클러스터 중앙 근처
	_add_prop("Prop_Wagon", Vector3(8, 0, 6), 0.6)
	_add_prop("Prop_Crate", Vector3(-6, 0.5, 8), 0.2)
	_add_prop("Prop_Crate", Vector3(-7, 0.5, 8.5), 0.9)
