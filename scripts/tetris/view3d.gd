extends Node3D
## 3D 보드 렌더 + VFX (라인 플래시/파편, 하드드롭 더스트, 카메라 셰이크, 팝업).

const CELL := 1.0
const VW := 10.0
const SWAY_PERIOD := 14.0 # 왕복 주기(초)
const SWAY_MAX_DEG := 30.0
const ORBIT_R := 27.0
const CAM_H := 11.0
const CENTER := Vector3(0, 9, 0)

var game: TetrisGame = null

var _cube_mesh := BoxMesh.new()
var _mats := {} # 색인덱스 -> material
var _ghost_mat: StandardMaterial3D
var _locked: Dictionary = {} # "c,r" -> MeshInstance3D
var _active_root := Node3D.new()
var _ghost_root := Node3D.new()
var _fx_root := Node3D.new()
var _last_sig := ""
var _debris: Array = []
var _shake := 0.0
var _time := 0.0
var _cam: Camera3D
var _cam_base := Vector3.ZERO

func _ready() -> void:
	_cube_mesh.size = Vector3(0.92, 0.92, 0.92)
	_build_materials()
	_build_stage()
	add_child(_active_root)
	add_child(_ghost_root)
	add_child(_fx_root)

func attach(g: TetrisGame) -> void:
	game = g
	game.connect("grid_changed", _rebuild_locked)
	game.connect("active_changed", _refresh_active)
	game.connect("cleared", _on_cleared)
	game.connect("hard_dropped", _on_hard_drop)
	_rebuild_locked()
	_refresh_active()

func cell_pos(c: int, r: int) -> Vector3:
	return Vector3((float(c) - 4.5) * CELL, float(TetrisGame.ROWS - 1 - r) * CELL + CELL * 0.5, 0.0)

func _mat_for(idx: int) -> StandardMaterial3D:
	if _mats.has(idx):
		return _mats[idx]
	var names := ["I", "O", "T", "S", "Z", "J", "L"]
	var col: Color = TetrisPieces.COLORS[names[idx - 1]]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.15
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = col * 0.35
	_mats[idx] = m
	return m

func _build_materials() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(1, 1, 1, 0.22)
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _build_stage() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-25), 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 10, 10)
	fill.light_energy = 0.5
	fill.omni_range = 40.0
	add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.55)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	_cam = Camera3D.new()
	add_child(_cam)
	# 중앙 정면 시작 → 이후 ±30° 왕복 (_process에서 갱신)
	_time = 0.0
	_cam.position = Vector3(CENTER.x, CAM_H, CENTER.z + ORBIT_R)
	_cam.look_at(CENTER)
	_cam.fov = 55.0
	_cam.current = true
	_cam_base = _cam.position
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.09, 0.16)
	dark.roughness = 0.9
	# 바닥
	_add_box(Vector3(0, -0.3, 0), Vector3(12.5, 0.6, 5), dark)
	# 뒷판 (가시 20행)
	_add_box(Vector3(0, 10.0, -0.7), Vector3(12.5, 21.0, 0.4), dark)
	# 좌우 기둥
	_add_box(Vector3(-5.6, 10.0, 0), Vector3(0.7, 21.5, 2.2), dark)
	_add_box(Vector3(5.6, 10.0, 0), Vector3(0.7, 21.5, 2.2), dark)
	# 상단 바
	_add_box(Vector3(0, 20.6, 0), Vector3(12.0, 0.7, 2.2), dark)
	# 행 그리드선
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.2, 0.25, 0.4)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for r in range(TetrisGame.HIDDEN, TetrisGame.ROWS):
		var y := float(TetrisGame.ROWS - 1 - r) * CELL
		_add_box(Vector3(0, y, 0.42), Vector3(10.0, 0.03, 0.03), line_mat)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

func _key(c: int, r: int) -> String:
	return "%d,%d" % [c, r]

func _rebuild_locked() -> void:
	if game == null:
		return
	var want := {}
	for r in TetrisGame.ROWS:
		for c in TetrisGame.COLS:
			var v: int = (game.grid[r] as Array)[c]
			if v != 0:
				want[_key(c, r)] = v
	for k in _locked.keys():
		if not want.has(k):
			(_locked[k] as Node).queue_free()
			_locked.erase(k)
	for k in want.keys():
		if _locked.has(k):
			continue
		var parts := (k as String).split(",")
		var mi := MeshInstance3D.new()
		mi.mesh = _cube_mesh
		mi.material_override = _mat_for(int(want[k]))
		mi.position = cell_pos(int(parts[0]), int(parts[1]))
		add_child(mi)
		_locked[k] = mi

func _refresh_active() -> void:
	if game == null:
		return
	for ch in _active_root.get_children():
		ch.queue_free()
	for ch in _ghost_root.get_children():
		ch.queue_free()
	if game.active_type == "":
		return
	var idx: int = TetrisPieces.COLOR_INDEX[game.active_type]
	for c in game.active_cells():
		var v: Vector2i = c
		var mi := MeshInstance3D.new()
		mi.mesh = _cube_mesh
		mi.material_override = _mat_for(idx)
		mi.position = cell_pos(v.x, v.y)
		_active_root.add_child(mi)
	for c in game.ghost_cells():
		var v: Vector2i = c
		var mi := MeshInstance3D.new()
		mi.mesh = _cube_mesh
		mi.material_override = _ghost_mat
		mi.position = cell_pos(v.x, v.y)
		_ghost_root.add_child(mi)

func _process(delta: float) -> void:
	# 시야 왕복: 중앙(0°) 시작 → ±30°
	_time += delta
	var th := deg_to_rad(SWAY_MAX_DEG) * sin(_time * TAU / SWAY_PERIOD)
	_cam_base = Vector3(CENTER.x + ORBIT_R * sin(th), CAM_H, CENTER.z + ORBIT_R * cos(th))
	_cam.position = _cam_base
	_cam.look_at(CENTER)
	# 파편 업데이트
	for i in range(_debris.size() - 1, -1, -1):
		var d: Dictionary = _debris[i]
		d["vel"] = (d["vel"] as Vector3) + Vector3(0, -14, 0) * delta
		(d["node"] as Node3D).position += (d["vel"] as Vector3) * delta
		d["life"] = float(d["life"]) - delta
		var s := maxf(float(d["life"]) / 0.7, 0.01)
		(d["node"] as Node3D).scale = Vector3.ONE * s
		if float(d["life"]) <= 0.0:
			(d["node"] as Node3D).queue_free()
			_debris.remove_at(i)
	# 카메라 셰이크 감쇠
	if _shake > 0.001:
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 8.0))
		_cam.position = _cam_base + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.5
	else:
		_cam.position = _cam_base

func _on_cleared(rows: Array, label: String, points: int) -> void:
	for r in rows:
		var y := cell_pos(0, int(r)).y
		_flash_row(y)
		_burst_row(int(r))
	_shake = clampf(0.25 + rows.size() * 0.2, 0.0, 1.0)

func _flash_row(y: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10.0, 1.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(0, y, 0.55)
	mi.rotation = Vector3.ZERO
	_fx_root.add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(mi, "scale", Vector3(1, 3, 1), 0.3)
	tw.chain().tween_callback(mi.queue_free)

func _burst_row(r: int) -> void:
	for c in TetrisGame.COLS:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.3, 0.3)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1)
		mi.material_override = m
		mi.position = cell_pos(c, r)
		_fx_root.add_child(mi)
		_debris.append({
			"node": mi,
			"vel": Vector3(randf_range(-4, 4), randf_range(3, 9), randf_range(-1, 3)),
			"life": 0.7,
		})

func _on_hard_drop(cells: Array) -> void:
	_shake = maxf(_shake, 0.3)
	for c in cells:
		var v: Vector2i = c
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.2, 0.35)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.8, 0.85, 1.0, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = cell_pos(v.x, v.y) + Vector3(0, -0.4, 0.3)
		_fx_root.add_child(mi)
		_debris.append({"node": mi, "vel": Vector3(randf_range(-2, 2), randf_range(1, 4), 0), "life": 0.4})
