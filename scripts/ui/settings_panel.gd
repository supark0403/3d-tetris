extends PanelContainer
## 공용 설정 패널: 볼륨 2종 + 키 리바인딩 7종. 메인 메뉴·일시정지에 임베드.

var listening_action := ""
var _key_buttons := {}

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var t := Label.new()
	t.text = "설정"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(t, 24, true)
	vbox.add_child(t)
	_add_vol_row(vbox, "마스터 볼륨", Settings.master_volume, func(v: float) -> void:
		Settings.master_volume = v
		Settings.apply()
		Settings.save_settings())
	_add_vol_row(vbox, "효과음 볼륨", Settings.sfx_volume, func(v: float) -> void:
		Settings.sfx_volume = v
		Settings.apply()
		Settings.save_settings())
	var kt := Label.new()
	kt.text = "키 설정 (클릭 후 키 입력, Esc=취소·고정키 P/Esc·R 제외)"
	_font(kt, 14, true)
	kt.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	vbox.add_child(kt)
	for a in Settings.GAME_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)
		var l := Label.new()
		l.text = String(Settings.ACTION_LABELS[a])
		l.custom_minimum_size = Vector2(150, 0)
		_font(l, 16)
		row.add_child(l)
		var b := Button.new()
		b.text = Settings.key_name(a)
		b.custom_minimum_size = Vector2(150, 36)
		_font(b, 16, true)
		b.pressed.connect(_on_key_button.bind(a))
		row.add_child(b)
		_key_buttons[a] = b
	var reset_btn := Button.new()
	reset_btn.text = "키 기본값으로"
	_font(reset_btn, 15, true)
	reset_btn.custom_minimum_size = Vector2(0, 40)
	reset_btn.pressed.connect(func() -> void:
		Settings.reset_keys()
		listening_action = ""
		_refresh_key_buttons())
	vbox.add_child(reset_btn)

func _on_key_button(action: String) -> void:
	listening_action = action
	(_key_buttons[action] as Button).text = "··· 입력 대기"

func _input(event: InputEvent) -> void:
	if listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			listening_action = ""
			_refresh_key_buttons()
		else:
			_assign_key(listening_action, int(k.physical_keycode))
			listening_action = ""
			_refresh_key_buttons()
		get_viewport().set_input_as_handled()

func _assign_key(action: String, code: int) -> void:
	# 충돌 시 맞교환 (미지정 상태 방지)
	for a in Settings.GAME_ACTIONS:
		if a != action and int(Settings.bindings.get(a, 0)) == code:
			Settings.bindings[a] = Settings.bindings[action]
	Settings.bindings[action] = code
	Settings.apply_bindings()
	Settings.save_settings()

func _refresh_key_buttons() -> void:
	for a in _key_buttons.keys():
		(_key_buttons[a] as Button).text = Settings.key_name(a)

func _add_vol_row(parent: VBoxContainer, title: String, val: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = "%s: %d%%" % [title, int(val * 100.0)]
	_font(l, 16, true)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(310, 24)
	s.value_changed.connect(func(v: float) -> void:
		l.text = "%s: %d%%" % [title, int(v * 100.0)]
		cb.call(v))
	parent.add_child(s)

func _font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)
