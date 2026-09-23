extends Node3D
## 웨이브 디렉터: 10분(600초) 생존 스폰 관리 + 난이도 램프 + 처치 집계
## 거인 5티어 가중치가 시간에 따라 대형 쪽으로 이동 (뱀파이어 서바이벌식)

signal time_changed(remain: float, total: float)
signal kills_changed(kills: int)
signal survived # 600초 버팀

const SURVIVE_TIME := 600.0

var player: Node3D = null
var elapsed := 0.0
var kills := 0
var spawn_timer := 0.0
var running := false
var max_alive := 14

var _titan_script: Script = preload("res://scripts/titan/titan.gd")

func start(p: Node3D) -> void:
	player = p
	elapsed = 0.0
	kills = 0
	spawn_timer = 1.0
	running = true
	emit_signal("time_changed", SURVIVE_TIME, SURVIVE_TIME)
	emit_signal("kills_changed", kills)

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running or not is_instance_valid(player):
		return
	elapsed += delta
	var remain := maxf(0.0, SURVIVE_TIME - elapsed)
	emit_signal("time_changed", remain, SURVIVE_TIME)
	if remain <= 0.0:
		running = false
		emit_signal("survived")
		return
	# 난이도 램프
	var k := elapsed / SURVIVE_TIME # 0..1
	max_alive = int(lerpf(10.0, 42.0, k))
	var interval := lerpf(2.6, 0.65, k)
	spawn_timer -= delta
	var alive := get_tree().get_nodes_in_group("titan").size()
	if spawn_timer <= 0.0 and alive < max_alive:
		spawn_timer = interval
		var batch := 1
		if k > 0.5 and randf() < 0.4:
			batch = 2
		if k > 0.8 and randf() < 0.3:
			batch = 3
		for i in batch:
			_spawn_one(k)
	_separate_titans(delta)

func _tier_roll(k: float) -> int:
	# 초반 소형 위주 -> 후반 대형 비중 상승
	var r := randf()
	if k < 0.2:
		if r < 0.55: return 0
		if r < 0.85: return 1
		return 2
	elif k < 0.45:
		if r < 0.3: return 0
		if r < 0.6: return 1
		if r < 0.85: return 2
		return 3
	elif k < 0.7:
		if r < 0.15: return 0
		if r < 0.4: return 1
		if r < 0.7: return 2
		if r < 0.92: return 3
		return 4
	else:
		if r < 0.08: return 0
		if r < 0.25: return 1
		if r < 0.55: return 2
		if r < 0.85: return 3
		return 4

func _spawn_one(k: float) -> void:
	var t := CharacterBody3D.new()
	t.set_script(_titan_script)
	add_child(t)
	var tier := _tier_roll(k)
	t.setup(tier, player)
	# 스폰 위치: 플레이어 주변 링(반경 55~85), 아레나 범위 클램프
	var ang := randf() * TAU
	var dist := randf_range(55.0, 85.0)
	var pos: Vector3 = player.global_position + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
	pos.x = clampf(pos.x, -95.0, 95.0)
	pos.z = clampf(pos.z, -95.0, 95.0)
	pos.y = 3.0
	t.global_position = pos
	t.connect("killed", _on_titan_killed)

func _on_titan_killed(titan: Node3D, tier: int, xp_value: float) -> void:
	kills += 1
	emit_signal("kills_changed", kills)

func _separate_titans(delta: float) -> void:
	var titans := get_tree().get_nodes_in_group("titan")
	if titans.size() < 2:
		return
	# O(n^2) 방지: 샘플 40마리까지만
	var n := mini(titans.size(), 40)
	for i in n:
		var a := titans[i] as Node3D
		if a == null:
			continue
		for j in range(i + 1, n):
			var b := titans[j] as Node3D
			if b == null:
				continue
			var d: Vector3 = a.global_position - b.global_position
			d.y = 0.0
			var dist := d.length()
			if dist < 0.01:
				continue
			if dist < 3.5:
				var push: Vector3 = d.normalized() * (3.5 - dist) * 2.0 * delta
				if a.has_method("add_separation"):
					a.add_separation(push)
				if b.has_method("add_separation"):
					b.add_separation(-push)
