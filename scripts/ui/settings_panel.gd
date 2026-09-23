extends PanelContainer
## 설정 패널(재사용): 마우스 감도, 마스터/음악/SFX 볼륨
## 메인 메뉴 + 일시정지 메뉴에 임베드.

signal closed

var _sens_slider: HSlider
var _sens_label: Label
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider

func _ready() -> void:
	_apply_theme()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	vbox.add_child(_title_label("설정"))
	_sens_slider, _sens_label = _add_slider_row(vbox, "마우스 감도", 0.1, 3.0, Settings.mouse_sensitivity)
	_sens_slider.value_changed.connect(func(v: float):
		Settings.mouse_sensitivity = v
		_sens_label.text = "%.2f" % v
		Settings.save_settings())
	_master_slider = _add_simple_slider(vbox, "마스터 볼륨", Settings.master_volume, func(v: float):
		Settings.master_volume = v
		Settings.apply_volumes()
		Settings.save_settings())
	_music_slider = _add_simple_slider(vbox, "음악 볼륨", Settings.music_volume, func(v: float):
		Settings.music_volume = v
		Settings.apply_volumes()
		Settings.save_settings())
	_sfx_slider = _add_simple_slider(vbox, "효과음 볼륨", Settings.sfx_volume, func(v: float):
		Settings.sfx_volume = v
		Settings.apply_volumes()
		Settings.save_settings())
	var hint := Label.new()
	hint.text = "V: 1인칭/3인칭 전환  |  Q/E: 좌/우 훅  |  F·우클릭: 양쪽 훅  |  좌클릭: 공격  |  Shift: 가스 부스트"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(hint, 14)
	vbox.add_child(hint)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(140, 44)
	_style_button(close_btn)
	btn_row.add_child(close_btn)
	close_btn.pressed.connect(func() -> void:
		AudioManager.click()
		emit_signal("closed"))

func _title_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(l, 26, true)
	return l

func _add_slider_row(parent: VBoxContainer, title: String, mn: float, mx: float, val: float) -> Array:
	var row := VBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = "%s: %.2f" % [title, val]
	_apply_font(l, 16)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(0, 28)
	row.add_child(s)
	s.value_changed.connect(func(v: float): l.text = "%s: %.2f" % [title, v])
	return [s, l]

func _add_simple_slider(parent: VBoxContainer, title: String, val: float, cb: Callable) -> HSlider:
	var arr: Array = _add_slider_row(parent, title, 0.0, 1.0, val)
	var s: HSlider = arr[0]
	s.value_changed.connect(cb)
	return s

func _apply_theme() -> void:
	var theme_path := "res://assets/gui/GuiAssets/gdp_theme.tres"
	if ResourceLoader.exists(theme_path):
		var th: Theme = load(theme_path)
		if th != null:
			theme = th

func _apply_font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f != null:
			c.add_theme_font_override("font", f)
			c.add_theme_font_size_override("font_size", size)

func _style_button(b: Button) -> void:
	_apply_font(b, 18, true)
