extends CanvasLayer
## HUD: HP/가스/XP 바, 타이머, 처치수, 레벨, 조준점, 데미지 플래시, 레벨업 패널 호스트

var hp_bar: ProgressBar
var gas_bar: ProgressBar
var xp_bar: ProgressBar
var timer_label: Label
var kills_label: Label
var level_label: Label
var crosshair: Label
var hook_label: Label
var _flash: ColorRect
var _levelup_layer: Control = null

func _ready() -> void:
	layer = 10
	_build()

func _font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)

func _build() -> void:
	var theme_path := "res://assets/gui/GuiAssets/gdp_theme.tres"
	var th: Theme = null
	if ResourceLoader.exists(theme_path):
		th = load(theme_path)
	# 상단 중앙 타이머
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-160, 10)
	top.custom_minimum_size = Vector2(320, 0)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(top)
	timer_label = Label.new()
	timer_label.text = "10:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(timer_label, 40, true)
	timer_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	top.add_child(timer_label)
	kills_label = Label.new()
	kills_label.text = "처치 0"
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(kills_label, 18, true)
	top.add_child(kills_label)
	# 좌하단 HP/가스
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(16, -130)
	bl.custom_minimum_size = Vector2(300, 0)
	bl.add_theme_constant_override("separation", 6)
	add_child(bl)
	var hp_l := Label.new()
	hp_l.text = "체력"
	_font(hp_l, 15, true)
	bl.add_child(hp_l)
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.custom_minimum_size = Vector2(300, 22)
	hp_bar.show_percentage = false
	if th != null:
		hp_bar.theme = th
	bl.add_child(hp_bar)
	var gas_l := Label.new()
	gas_l.text = "가스"
	_font(gas_l, 15, true)
	bl.add_child(gas_l)
	gas_bar = ProgressBar.new()
	gas_bar.min_value = 0
	gas_bar.max_value = 100
	gas_bar.value = 100
	gas_bar.custom_minimum_size = Vector2(300, 16)
	gas_bar.show_percentage = false
	if th != null:
		gas_bar.theme = th
	bl.add_child(gas_bar)
	# 하단 XP
	xp_bar = ProgressBar.new()
	xp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	xp_bar.offset_left = 0
	xp_bar.offset_right = 0
	xp_bar.offset_top = -22
	xp_bar.offset_bottom = -8
	xp_bar.show_percentage = false
	if th != null:
		xp_bar.theme = th
	add_child(xp_bar)
	level_label = Label.new()
	level_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	level_label.position = Vector2(-220, -160)
	level_label.text = "Lv.1"
	_font(level_label, 22, true)
	add_child(level_label)
	# 조준점
	crosshair = Label.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12, -18)
	crosshair.text = "＋"
	_font(crosshair, 28, true)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	add_child(crosshair)
	hook_label = Label.new()
	hook_label.set_anchors_preset(Control.PRESET_CENTER)
	hook_label.position = Vector2(-140, 30)
	hook_label.custom_minimum_size = Vector2(280, 0)
	hook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook_label.text = ""
	_font(hook_label, 15, true)
	hook_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	add_child(hook_label)
	# 피격 플래시
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 0, 0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func bind_player(p: Node) -> void:
	p.connect("hp_changed", _on_hp)
	p.connect("gas_changed", _on_gas)
	p.connect("xp_changed", _on_xp)
	p.connect("leveled_up", _on_levelup.bind(p))

func bind_director(d: Node) -> void:
	d.connect("time_changed", _on_time)
	d.connect("kills_changed", func(k: int) -> void: kills_label.text = "처치 %d" % k)

func _on_hp(hp: float, mx: float) -> void:
	hp_bar.max_value = mx
	hp_bar.value = hp
	if hp < mx * 0.35:
		_flash.color = Color(1, 0, 0, 0.22)
		var tw := create_tween()
		tw.tween_property(_flash, "color:a", 0.0, 0.4)

func _on_gas(g: float, mx: float) -> void:
	gas_bar.max_value = mx
	gas_bar.value = g

func _on_xp(xp: float, need: float, level: int) -> void:
	xp_bar.max_value = need
	xp_bar.value = xp
	level_label.text = "Lv.%d" % level

func _on_time(remain: float, total: float) -> void:
	var m := int(remain) / 60
	var s := int(remain) % 60
	timer_label.text = "%d:%02d" % [m, s]
	if remain < 60.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))

func set_hook_text(l_on: bool, r_on: bool) -> void:
	if l_on and r_on:
		hook_label.text = "◀ 훅 고정 ▶  (Shift: 가스 분사)"
	elif l_on:
		hook_label.text = "◀ 좌측 훅 고정"
	elif r_on:
		hook_label.text = "우측 훅 고정 ▶"
	else:
		hook_label.text = ""

func _on_levelup(new_level: int, player: Node) -> void:
	_show_levelup(player)

func _show_levelup(player: Node) -> void:
	if is_instance_valid(_levelup_layer):
		return
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	_levelup_layer = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var t := Label.new()
	t.text = "LEVEL UP!  Lv.%d — 강화 선택" % player.level
	_font(t, 22, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	var opts := [
		["damage", "⚔ 블레이드 강화 (+25% 공격력)"],
		["hp", "❤ 체력 강화 (+25 최대체력·회복)"],
		["speed", "👟 기동 강화 (+12% 이동속도)"],
		["range", "🪝 훅 강화 (+20% 사거리)"],
		["crit", "💥 목덜미 Bere (+치명타)"],
	]
	var picks := opts.duplicate()
	picks.shuffle()
	for i in 3:
		var kind: String = picks[i][0]
		var label: String = picks[i][1]
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(0, 48)
		_font(b, 17, true)
		var theme_path := "res://assets/gui/GuiAssets/gdp_theme.tres"
		if ResourceLoader.exists(theme_path):
			b.theme = load(theme_path)
		b.pressed.connect(func() -> void:
			AudioManager.click()
			player.apply_upgrade(kind)
			if is_instance_valid(dim):
				dim.queue_free()
			_levelup_layer = null
			get_tree().paused = false)
		vbox.add_child(b)
