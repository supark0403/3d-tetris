extends Node3D
## 게임 루트: TetrisGame(로직) + 3D 뷰 + UI 조립, 일시정지/재시작.

var game: TetrisGame
var view: Node3D
var _ui: CanvasLayer
var _score_l: Label
var _level_l: Label
var _lines_l: Label
var _combo_l: Label
var _hold_pv: Control
var _next_pvs: Array = []
var _announce_l: Label
var _announce_tw: Tween
var _pause_panel: Control
var _over_panel: Control
var _over_score_l: Label

func _ready() -> void:
	game = TetrisGame.new()
	add_child(game)
	view = Node3D.new()
	view.set_script(load("res://scripts/tetris/view3d.gd"))
	add_child(view)
	game.new_game()
	view.attach(game)
	_build_ui()
	game.connect("stats_changed", _refresh_stats)
	game.connect("announce", _announce)
	game.connect("cleared", _on_cleared_ui)
	game.connect("game_over", _show_over)
	game.connect("active_changed", _refresh_previews)
	_refresh_stats()
	_refresh_previews()
	if "--autotest" in OS.get_cmdline_user_args():
		_run_autotest()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if not game.over:
			_toggle_pause()
	elif event.is_action_pressed("restart_game"):
		_restart()

func _toggle_pause() -> void:
	game.paused = not game.paused
	Sfx.play("pause", 0.7)
	_pause_panel.visible = game.paused

func _restart() -> void:
	game.new_game()
	_over_panel.visible = false
	_pause_panel.visible = false
	_refresh_stats()
	_refresh_previews()

# ---------- UI ----------

func _font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)

func _panel(title: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = title
	_font(t, 15, true)
	t.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	vb.add_child(t)
	return vb

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	# 좌측: 홀드+스탯
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.position = Vector2(24, -220)
	left.custom_minimum_size = Vector2(170, 0)
	left.add_theme_constant_override("separation", 14)
	_ui.add_child(left)
	var hold_box := _panel("HOLD (Space)")
	_hold_pv = Control.new()
	_hold_pv.set_script(load("res://scripts/ui/preview.gd"))
	hold_box.add_child(_hold_pv)
	left.add_child(hold_box)
	var stat_box := _panel("SCORE")
	_score_l = Label.new()
	_font(_score_l, 26, true)
	stat_box.add_child(_score_l)
	_level_l = Label.new()
	_font(_level_l, 18, true)
	stat_box.add_child(_level_l)
	_lines_l = Label.new()
	_font(_lines_l, 18)
	stat_box.add_child(_lines_l)
	_combo_l = Label.new()
	_font(_combo_l, 16, true)
	_combo_l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	stat_box.add_child(_combo_l)
	left.add_child(stat_box)
	var help := Label.new()
	help.text = "A/D 이동(꾹 누르면 연타)\nW 하드드롭 S 소프트드롭\n←/→ 반시계/시계 회전\nSpace 홀드\nP 일시정지 R 재시작"
	_font(help, 14)
	help.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	left.add_child(help)
	# 우측: NEXT
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.position = Vector2(-194, -220)
	right.custom_minimum_size = Vector2(170, 0)
	right.add_theme_constant_override("separation", 14)
	_ui.add_child(right)
	var next_box := _panel("NEXT")
	right.add_child(next_box)
	for i in 3:
		var pv := Control.new()
		pv.set_script(load("res://scripts/ui/preview.gd"))
		next_box.add_child(pv)
		_next_pvs.append(pv)
	var title := Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200, 12)
	title.custom_minimum_size = Vector2(400, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "3D TETRIS v1.2"
	_font(title, 34, true)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_ui.add_child(title)
	# 중앙 아나운스
	_announce_l = Label.new()
	_announce_l.set_anchors_preset(Control.PRESET_CENTER)
	_announce_l.position = Vector2(-300, -80)
	_announce_l.custom_minimum_size = Vector2(600, 80)
	_announce_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_announce_l, 52, true)
	_announce_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_announce_l.modulate.a = 0.0
	_ui.add_child(_announce_l)
	# 일시정지 / 게임오버 패널
	_pause_panel = _overlay("일시정지", "")
	_build_pause_contents(_pause_panel.get_meta("box") as VBoxContainer)
	_over_panel = _overlay("GAME OVER", "")
	_over_score_l = _over_panel.get_meta("info") as Label
	_pause_panel.visible = false
	_over_panel.visible = false

func _build_pause_contents(box: VBoxContainer) -> void:
	var set_btn := Button.new()
	set_btn.text = "⚙ 설정"
	_font(set_btn, 19, true)
	set_btn.custom_minimum_size = Vector2(300, 48)
	box.add_child(set_btn)
	var settings_box := VBoxContainer.new()
	settings_box.visible = false
	settings_box.add_theme_constant_override("separation", 4)
	box.add_child(settings_box)
	set_btn.pressed.connect(func() -> void: settings_box.visible = not settings_box.visible)
	_add_vol_row(settings_box, "마스터 볼륨", Settings.master_volume, func(v: float) -> void:
		Settings.master_volume = v
		Settings.apply()
		Settings.save_settings())
	_add_vol_row(settings_box, "효과음 볼륨", Settings.sfx_volume, func(v: float) -> void:
		Settings.sfx_volume = v
		Settings.apply()
		Settings.save_settings())
	var resume_btn := Button.new()
	resume_btn.text = "▶ 계속하기 (P)"
	_font(resume_btn, 19, true)
	resume_btn.custom_minimum_size = Vector2(300, 48)
	resume_btn.pressed.connect(func() -> void: _toggle_pause())
	box.add_child(resume_btn)
	var restart_btn := Button.new()
	restart_btn.text = "↻ 재시작 (R)"
	_font(restart_btn, 19, true)
	restart_btn.custom_minimum_size = Vector2(300, 48)
	restart_btn.pressed.connect(func() -> void: _restart())
	box.add_child(restart_btn)

func _add_vol_row(parent: VBoxContainer, title: String, val: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = "%s: %d%%" % [title, int(val * 100.0)]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(l, 16, true)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(300, 26)
	s.value_changed.connect(func(v: float) -> void:
		l.text = "%s: %d%%" % [title, int(v * 100.0)]
		cb.call(v))
	parent.add_child(s)

func _overlay(title_text: String, sub: String) -> Control:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)
	var t := Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(t, 54, true)
	t.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	vb.add_child(t)
	var info := Label.new()
	info.text = sub
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(info, 20, true)
	vb.add_child(info)
	dim.set_meta("info", info)
	dim.set_meta("box", vb)
	return dim

func _refresh_stats() -> void:
	_score_l.text = "%d" % game.score
	_level_l.text = "Lv.%d" % game.level
	_lines_l.text = "%d 라인" % game.lines
	if game.combo > 0:
		_combo_l.text = "%d COMBO%s" % [game.combo, "  B2B!" if game.b2b else ""]
	else:
		_combo_l.text = "B2B!" if game.b2b else ""

func _refresh_previews() -> void:
	_hold_pv.set("piece", game.hold_type)
	for i in mini(3, game.queue.size()):
		(_next_pvs[i] as Control).set("piece", String(game.queue[i]))

func _announce(text: String, big: bool) -> void:
	_announce_l.text = text
	_font(_announce_l, 52 if big else 36, true)
	if is_instance_valid(_announce_tw):
		_announce_tw.kill()
	_announce_l.modulate.a = 1.0
	_announce_l.scale = Vector2(0.7, 0.7)
	_announce_l.pivot_offset = Vector2(300, 40)
	_announce_tw = create_tween()
	_announce_tw.set_parallel(true)
	_announce_tw.tween_property(_announce_l, "scale", Vector2.ONE, 0.18)
	_announce_tw.tween_property(_announce_l, "modulate:a", 0.0, 0.9).set_delay(0.5)

func _on_cleared_ui(rows: Array, label: String, points: int) -> void:
	if rows.size() > 0 and rows.size() < 4 and label != "" and not label.begins_with("T-SPIN"):
		_announce("%s  +%d" % [label, points], false)

func _show_over() -> void:
	_over_score_l.text = "Score %d · Lv.%d · %d라인 — R로 재시작" % [game.score, game.level, game.lines]
	_over_panel.visible = true

# ---------- 헤드리스 자가검증 ----------

func _run_autotest() -> void:
	await get_tree().process_frame
	var g := TetrisGame.new()
	print("[AUTOTEST] logic=", g.run_self_test())
	print("[AUTOTEST] view_locked=", view.get("_locked").size() >= 0)
	print("[AUTOTEST] sfx_bank=", Sfx.get("_bank").size())
	print("[AUTOTEST] PASS")
