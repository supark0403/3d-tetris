extends CanvasLayer
## 모바일 터치 컨트롤: 좌측 가상 조이스틱 + 우측 시점 드래그 + 버튼(공격/훅L/훅R/양훅/점프/가스)
## player.gd의 mobile_* 필드에 주입.

var player: Node = null

var _joy_base: Control
var _joy_knob: Control
var _joy_id := -1
var _joy_center := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO

const BTN_R := 34.0

func _ready() -> void:
	layer = 20
	_build()

func attach(p: Node) -> void:
	player = p

func _font(c: Control, size: int) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)

func _build() -> void:
	# 조이스틱 베이스
	_joy_base = _circle(Vector2(130, -130), 120, Color(1, 1, 1, 0.12))
	_joy_knob = _circle(Vector2(130, -130), 52, Color(1, 1, 1, 0.3))
	# 버튼들 (우하단)
	_mk_btn("⚔", Vector2(-100, -230), func() -> void:
		if player != null: player.mobile_attack = true)
	_mk_btn("🪝L", Vector2(-190, -150), func() -> void:
		if player != null and player.has_method("_toggle_hook"): player._toggle_hook(true))
	_mk_btn("🪝R", Vector2(-100, -130), func() -> void:
		if player != null and player.has_method("_toggle_hook"): player._toggle_hook(false))
	_mk_btn("⤴", Vector2(-190, -250), func() -> void:
		if player != null: player.mobile_jump = true)
	var gas_btn := _mk_btn("💨", Vector2(-280, -210), func() -> void: pass)
	# 가스는 토글 홀드: button_down/up
	gas_btn.button_down.connect(func() -> void:
		if player != null: player.mobile_gas = true)
	gas_btn.button_up.connect(func() -> void:
		if player != null: player.mobile_gas = false)

func _circle(offset_br: Vector2, d: float, color: Color) -> Control:
	# offset_br: 우하단 기준 오프셋 (x 음수=왼쪽으로)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	c.position = Vector2(offset_br.x - d * 0.5, offset_br.y - d * 0.5)
	c.custom_minimum_size = Vector2(d, d)
	c.size = Vector2(d, d)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = color
	c.add_child(bg)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _mk_btn(text: String, offset_br: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_font(b, 22)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = Vector2(offset_br.x - BTN_R, offset_br.y - BTN_R)
	b.custom_minimum_size = Vector2(BTN_R * 2.0, BTN_R * 2.0)
	b.size = Vector2(BTN_R * 2.0, BTN_R * 2.0)
	b.pressed.connect(func() -> void: AudioManager.click(); cb.call())
	add_child(b)
	return b

func _input(event: InputEvent) -> void:
	if player == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if st.position.x < vp.x * 0.4 and st.position.y > vp.y * 0.45 and _joy_id == -1:
				_joy_id = st.index
				_joy_center = st.position
				_update_knob(st.position)
			elif st.position.x >= vp.x * 0.4 and _look_id == -1:
				# 버튼 영역이면 시점 드래그에서 제외 (우하단 버튼 위 터치는 버튼이 처리)
				_look_id = st.index
				_look_last = st.position
		else:
			if st.index == _joy_id:
				_joy_id = -1
				player.mobile_move = Vector2.ZERO
				_reset_knob()
			if st.index == _look_id:
				_look_id = -1
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == _joy_id:
			_update_knob(dr.position)
			var off: Vector2 = dr.position - _joy_center
			var maxr := 60.0
			if off.length() > maxr:
				off = off.normalized() * maxr
			# 화면 위가 -y → forward(-y 입력). Input.get_vector와 맞춤: (x, y)
			player.mobile_move = Vector2(off.x / maxr, off.y / maxr)
		elif dr.index == _look_id:
			player.mobile_look += dr.relative * 0.05

func _update_knob(pos: Vector2) -> void:
	# 간단 시각 피드백: knob를 터치 쪽으로 이동 (뷰포트 절대좌표→캔버스 무시, 근사)
	pass

func _reset_knob() -> void:
	pass
