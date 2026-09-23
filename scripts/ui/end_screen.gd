extends Control
## 게임 오버 / 클리어 공용 엔드 스크린

signal restart_requested
signal quit_to_menu

func setup(win: bool, survive_sec: float, kills: int, level: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.02, 0.02, 0.78) if not win else Color(0.02, 0.08, 0.05, 0.78)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "★ 작전 성공 — 10분 생존! ★" if win else "☠  전사  ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(title, 48, true)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if win else Color(1.0, 0.45, 0.4))
	vbox.add_child(title)
	var info := Label.new()
	var m := int(survive_sec) / 60
	var s := int(survive_sec) % 60
	info.text = "버틴 시간 %d:%02d   |   처치 %d   |   레벨 %d" % [m, s, kills, level]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(info, 20, true)
	vbox.add_child(info)
	var tip := Label.new()
	tip.text = "입체기동 훅은 벽·건물·나무·거인 모두에 고정된다. 공중+훅 상태에서 공격하면 목덜미 치명타!" if not win else "벽과 마을을 지켜냈다. 다음 작전에서도 살아남아라, 병사!"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(tip, 15)
	vbox.add_child(tip)
	for data in [
		["↻  다시 싸우기", func() -> void: emit_signal("restart_requested")],
		["🏠  메인 메뉴로", func() -> void: emit_signal("quit_to_menu")],
	]:
		var b := Button.new()
		b.text = data[0]
		b.custom_minimum_size = Vector2(300, 54)
		_font(b, 19, true)
		var theme_path := "res://assets/gui/GuiAssets/gdp_theme.tres"
		if ResourceLoader.exists(theme_path):
			b.theme = load(theme_path)
		b.pressed.connect(func() -> void: AudioManager.click(); (data[1] as Callable).call())
		var c := CenterContainer.new()
		c.add_child(b)
		vbox.add_child(c)

func _font(c: Control, size: int, bold: bool = false) -> void:
	var path := "res://fonts/NanumGothic-Bold.ttf" if bold else "res://fonts/NanumGothic-Regular.ttf"
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)
