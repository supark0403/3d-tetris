extends Control
## 메인 메뉴: 타이틀, PC/모바일 선택, 게임 시작, 설정, 종료
## 배경에 페인터리 스카이 에셋 사용.

signal start_requested
signal settings_requested(open: bool)

var _settings_panel: Control = null
var _pc_btn: Button
var _mobile_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	_build_layout()

func _build_bg() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex_path := "res://assets/sky/Painterly Sky BGs (175).png"
	if ResourceLoader.exists(tex_path):
		bg.texture = load(tex_path)
	else:
		bg.color = Color(0.12, 0.14, 0.2)
	add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)

func _font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)

func _build_layout() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	var title := Label.new()
	title.text = "진격의 서바이버"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(title, 64, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "입체기동으로 10분을 버텨라 — 벽과 마을, 거대수림의 결전"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(sub, 18)
	sub.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	vbox.add_child(sub)
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 10)
	vbox.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "플레이 방식:"
	_font(mode_label, 18, true)
	mode_row.add_child(mode_label)
	_pc_btn = _mk_button("🖥 PC", func() -> void: _set_mode("pc"))
	_mobile_btn = _mk_button("📱 모바일", func() -> void: _set_mode("mobile"))
	mode_row.add_child(_pc_btn)
	mode_row.add_child(_mobile_btn)
	_refresh_mode_buttons()
	var start_btn := _mk_button("⚔  게임 시작", func() -> void:
		AudioManager.click()
		emit_signal("start_requested"), 56)
	start_btn.custom_minimum_size = Vector2(300, 60)
	vbox.add_child(start_btn)
	var set_btn := _mk_button("⚙  설정", func() -> void:
		AudioManager.click()
		_toggle_settings())
	set_btn.custom_minimum_size = Vector2(300, 50)
	vbox.add_child(set_btn)
	if not OS.has_feature("web"):
		var quit_btn := _mk_button("종료", func() -> void: get_tree().quit())
		quit_btn.custom_minimum_size = Vector2(300, 50)
		vbox.add_child(quit_btn)
	var foot := Label.new()
	foot.text = "레인저(플레이어) × 베이스 캐릭터 거인 5종  |  Medieval Village + Stylized Nature  |  NanumGothic 폰트"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(foot, 13)
	foot.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	vbox.add_child(foot)

func _mk_button(text: String, cb: Callable, fsize: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 52)
	_font(b, fsize, true)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: AudioManager.hover())
	var theme_path := "res://assets/gui/GuiAssets/gdp_theme.tres"
	if ResourceLoader.exists(theme_path):
		var th: Theme = load(theme_path)
		b.theme = th
	return b

func _set_mode(m: String) -> void:
	Settings.platform = m
	Settings.save_settings()
	AudioManager.click()
	_refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
	var is_pc := Settings.platform != "mobile"
	_pc_btn.disabled = is_pc
	_mobile_btn.disabled = not is_pc
	_pc_btn.text = "🖥 PC" + (" ✓" if is_pc else "")
	_mobile_btn.text = "📱 모바일" + ("" if is_pc else " ✓")

func _toggle_settings() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
		_settings_panel = null
		emit_signal("settings_requested", false)
		return
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var scr: Script = load("res://scripts/ui/settings_panel.gd")
	panel.set_script(scr)
	center.add_child(panel)
	_settings_panel = dim
	# 닫히면 dim 제거
	panel.get_node(".").connect("closed", func() -> void:
		if is_instance_valid(dim):
			dim.queue_free()
		_settings_panel = null
		emit_signal("settings_requested", false))
	emit_signal("settings_requested", true)
