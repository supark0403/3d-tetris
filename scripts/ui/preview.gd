extends Control
## 홀드/NEXT 미리보기: 2D 미노 그리기.

var piece := "" : set = set_piece

func set_piece(t: String) -> void:
	piece = t
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(110, 70)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.12, 0.9))
	if piece == "" or not TetrisPieces.BASE.has(piece):
		return
	var cells: Array = TetrisPieces.BASE[piece]
	var col: Color = TetrisPieces.COLORS[piece]
	var s := 16.0
	if piece == "I":
		s = 14.0
	# 중심 정렬
	var minx := 99
	var maxx := -99
	var miny := 99
	var maxy := -99
	for c in cells:
		var v: Vector2i = c
		minx = mini(minx, v.x)
		maxx = maxi(maxx, v.x)
		miny = mini(miny, v.y)
		maxy = maxi(maxy, v.y)
	var w := float(maxx - minx + 1) * s
	var h := float(maxy - miny + 1) * s
	var ox := (size.x - w) * 0.5 - minx * s
	var oy := (size.y - h) * 0.5 - miny * s
	for c in cells:
		var v: Vector2i = c
		var r := Rect2(Vector2(ox + v.x * s + 1, oy + v.y * s + 1), Vector2(s - 2, s - 2))
		draw_rect(r, col)
		draw_rect(r, col.lightened(0.4), false, 2.0)
