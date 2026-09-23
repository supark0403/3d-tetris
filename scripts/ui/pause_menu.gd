extends Control
## 일시정지 메뉴: 계속하기, 설정(임베드), 메인으로, 재시작

signal resume_requested
signal restart_requested
signal quit_to_menu

var _settings_holder: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
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
	t.text = "일시정지"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(t, 30, true)
	vbox.add_child(t)
	for data in [
		["▶  계속하기", func() -> void: emit_signal("resume_requested")],
		["⚙  설정", _toggle_settings.bind(vbox)],
		["↻  재시작", func() -> void: emit_signal("restart_requested")],
		["🏠  메인 메뉴로", func() -> void: emit_signal("quit_to_menu")],
	]:
		var b := Button.new()
		b.text = data[0]
		b.custom_minimum_size = Vector2(0, 48)
		_font(b, 18, true)
		_theme_btn(b)
		b.pressed.connect(func() -> void: AudioManager.click(); (data[1] as Callable).call())
		vbox.add_child(b)

func _toggle_settings(vbox: VBoxContainer) -> void:
	if is_instance_valid(_settings_holder):
		_settings_holder.queue_free()
		_settings_holder = null
		return
	var p := PanelContainer.new()
	var scr: Script = load("res://scripts/ui/settings_panel.gd")
	p.set_script(scr)
	vbox.add_child(p)
	_settings_holder = p
	p.connect("closed", func() -> void:
		if is_instance_valid(p):
			p.queue_free()
		_settings_holder = null)

func _font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)

func _theme_btn(b: Button) -> void:
	var theme_path := "res://assets/gui/GuiAssets/gdp_theme.tres"
	if ResourceLoader.exists(theme_path):
		b.theme = load(theme_path)
