extends Node3D
## 게임 루트: 메뉴 ↔ 플레이 ↔ 일시정지 ↔ 오버/클리어 상태머신
## PC/모바일 분기, 마우스 캡처, HUD/디렉터 바인딩.

enum State { MENU, PLAYING, PAUSED, OVER, CLEAR }

var state: int = State.MENU
var _menu: Control = null
var _hud: CanvasLayer = null
var _pause: Control = null
var _end: Control = null
var _touch: CanvasLayer = null
var _arena: Node3D = null
var _player: CharacterBody3D = null
var _director: Node3D = null
var _elapsed := 0.0

const PlayerScript := preload("res://scripts/player/player.gd")
const ArenaScript := preload("res://scripts/world/arena_builder.gd")
const DirectorScript := preload("res://scripts/titan/titan_director.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_menu()
	if "--autotest" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.5).timeout
		print("[AUTOTEST] start_game")
		start_game()
		await get_tree().create_timer(2.0).timeout
		_autotest_tick()

var _autotest_done := false

func _autotest_tick() -> void:
	# 헤드리스 검증: 아레나/플레이어/디렉터/타이탄 스폰/훅/공격/일시정지/재개 경로 실행
	print("[AUTOTEST] state=", state, " arena=", is_instance_valid(_arena), " player=", is_instance_valid(_player))
	if is_instance_valid(_arena):
		print("[AUTOTEST] arena_children=", _arena.get_child_count())
	if is_instance_valid(_player):
		print("[AUTOTEST] player_pos=", _player.global_position, " hp=", _player.hp)
		_player._fire_hook(true)
		_player._fire_hook(false)
		print("[AUTOTEST] hooks=", _player.hook_l_on, _player.hook_r_on)
		_player._try_attack()
		_player.gain_xp(50.0)
		print("[AUTOTEST] level=", _player.level, " xp_need=", _player.xp_need)
		_player.take_damage(5.0)
		print("[AUTOTEST] hp_after_dmg=", _player.hp)
	if is_instance_valid(_director):
		print("[AUTOTEST] director_elapsed=", _director.elapsed, " kills=", _director.kills)
	pause_game()
	print("[AUTOTEST] paused=", state)
	resume_game()
	print("[AUTOTEST] resumed=", state)
	# 강제 타이탄 1마리 스폰 후 처치
	if is_instance_valid(_director):
		_director._spawn_one(0.5)
		await get_tree().create_timer(1.0).timeout
		var titans := get_tree().get_nodes_in_group("titan")
		print("[AUTOTEST] titans=", titans.size())
		for t in titans:
			if t.has_method("take_damage"):
				t.take_damage(9999.0)
		await get_tree().create_timer(1.0).timeout
		print("[AUTOTEST] kills_after=", _director.kills)
	print("[AUTOTEST] PASS")
	_autotest_done = true

func _show_menu() -> void:
	_clear_game_nodes()
	state = State.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scr: Script = load("res://scripts/ui/main_menu.gd")
	_menu = Control.new()
	_menu.set_script(scr)
	add_child(_menu)
	_menu.connect("start_requested", start_game)

func start_game() -> void:
	_clear_game_nodes()
	state = State.PLAYING
	_elapsed = 0.0
	var mobile := Settings.is_mobile()
	# 아레나
	_arena = Node3D.new()
	_arena.set_script(ArenaScript)
	add_child(_arena)
	_arena.call("build", mobile)
	# 플레이어
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScript)
	add_child(_player)
	_player.global_position = Vector3(0, 1.0, 0)
	# 디렉터
	_director = Node3D.new()
	_director.set_script(DirectorScript)
	add_child(_director)
	_director.call("start", _player)
	# HUD
	var hud_scr: Script = load("res://scripts/ui/hud.gd")
	_hud = CanvasLayer.new()
	_hud.set_script(hud_scr)
	add_child(_hud)
	# bind는 _ready 이후 프레임에 (CanvasLayer _ready 보장)
	await get_tree().process_frame
	if is_instance_valid(_hud) and _hud.has_method("bind_player"):
		_hud.bind_player(_player)
		_hud.bind_director(_director)
	# 모바일 터치 UI
	if mobile:
		var tscr: Script = load("res://scripts/ui/touch_controls.gd")
		_touch = CanvasLayer.new()
		_touch.set_script(tscr)
		add_child(_touch)
		await get_tree().process_frame
		if _touch.has_method("attach"):
			_touch.attach(_player)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 시그널
	_player.connect("died", _on_player_died)
	_director.connect("survived", _on_survived)

func _clear_game_nodes() -> void:
	for n in [_menu, _hud, _pause, _end, _touch, _arena, _player, _director]:
		if is_instance_valid(n):
			n.queue_free()
	_menu = null
	_hud = null
	_pause = null
	_end = null
	_touch = null
	_arena = null
	_player = null
	_director = null
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match state:
			State.PLAYING:
				pause_game()
			State.PAUSED:
				resume_game()

func _process(delta: float) -> void:
	if state == State.PLAYING and is_instance_valid(_player) and is_instance_valid(_hud):
		_elapsed += delta
		if _hud.has_method("set_hook_text"):
			_hud.set_hook_text(_player.hook_l_on, _player.hook_r_on)

func pause_game() -> void:
	if state != State.PLAYING:
		return
	if is_instance_valid(_hud) and _hud.get("_levelup_layer") != null and is_instance_valid(_hud.get("_levelup_layer")):
		return # 레벨업 선택 중에는 일시정지 금지 (모달 충돌 방지)
	state = State.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scr: Script = load("res://scripts/ui/pause_menu.gd")
	_pause = Control.new()
	_pause.set_script(scr)
	# CanvasLayer 없이 최상위 Control로 (3D 위에 그려지도록 z_index는 CanvasItem 기본)
	add_child(_pause)
	# 일시정지 중에도 UI 입력 받도록 process_mode 항상
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.connect("resume_requested", resume_game)
	_pause.connect("restart_requested", func() -> void: start_game())
	_pause.connect("quit_to_menu", func() -> void: _show_menu())

func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	if is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null
	get_tree().paused = false
	if not Settings.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.OVER
	if is_instance_valid(_director) and _director.has_method("stop"):
		_director.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 약간 연출 후 엔드 스크린
	await get_tree().create_timer(1.0, true, false, true).timeout
	_show_end(false)

func _on_survived() -> void:
	if state != State.PLAYING:
		return
	state = State.CLEAR
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_end(true)

func _show_end(win: bool) -> void:
	get_tree().paused = true
	var scr: Script = load("res://scripts/ui/end_screen.gd")
	_end = Control.new()
	_end.set_script(scr)
	add_child(_end)
	_end.process_mode = Node.PROCESS_MODE_ALWAYS
	var kills := 0
	if is_instance_valid(_director):
		kills = _director.kills
	var lvl := 1
	if is_instance_valid(_player):
		lvl = _player.level
	_end.call("setup", win, _elapsed, kills, lvl)
	_end.connect("restart_requested", func() -> void: start_game())
	_end.connect("quit_to_menu", func() -> void: _show_menu())
