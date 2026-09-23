class_name TetrisPieces
extends RefCounted
## 가이드라인 테트리스 데이터: 7종 미노, 색, SRS 킥 테이블(y-down 좌표).

const ORDER: Array[String] = ["I", "O", "T", "S", "Z", "J", "L"]

const COLORS := {
	"I": Color(0.0, 0.941, 0.941),
	"O": Color(0.941, 0.941, 0.0),
	"T": Color(0.627, 0.0, 0.941),
	"S": Color(0.0, 0.941, 0.0),
	"Z": Color(0.941, 0.0, 0.0),
	"J": Color(0.941, 0.627, 0.0),
	"L": Color(0.0, 0.0, 0.941),
}

const COLOR_INDEX := {"I": 1, "O": 2, "T": 3, "S": 4, "Z": 5, "J": 6, "L": 7}

const BASE := {
	"I": [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
	"O": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"T": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1)],
	"S": [Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0)],
	"Z": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)],
	"J": [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
	"L": [Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
}

# JLSTZ 킥 (from_state -> to_state). y-down 변환済.
const KICKS_JLSTZ := {
	0: {
		1: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
		3: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	},
	1: {
		0: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
		2: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	},
	2: {
		1: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
		3: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, -2)],
	},
	3: {
		2: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
		0: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	},
}

# I 킥 (y-down 변환済).
const KICKS_I := {
	0: {
		1: [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
		3: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
	},
	1: {
		0: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
		2: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
	},
	2: {
		1: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
		3: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	},
	3: {
		2: [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
		0: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	},
}

static func rotated(cells: Array, cw: bool) -> Array:
	var out: Array = []
	for c in cells:
		var v: Vector2i = c
		if cw:
			out.append(Vector2i(-v.y, v.x))
		else:
			out.append(Vector2i(v.y, -v.x))
	return out

static func cells_for(piece: String, rot: int) -> Array:
	var cells: Array = (BASE[piece] as Array).duplicate()
	var r := posmod(rot, 4)
	for i in r:
		cells = rotated(cells, true)
	return cells

static func kicks_for(piece: String, from_rot: int, to_rot: int) -> Array:
	if piece == "O":
		return [Vector2i(0, 0)]
	var table: Dictionary = KICKS_I if piece == "I" else KICKS_JLSTZ
	var f := posmod(from_rot, 4)
	var t := posmod(to_rot, 4)
	if table.has(f) and (table[f] as Dictionary).has(t):
		return (table[f] as Dictionary)[t]
	return [Vector2i(0, 0)]
