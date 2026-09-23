class_name TetrisGame
extends Node
## 가이드라인 테트리스 코어 로직 (렌더/UI 분리).
## 7-bag, SRS+킥, 고스트, 홀드(락당 1회), 락딜레이(0.5s/15회), T스핀 3코너,
## DAS(0.15s)/ARR(0.04s) — 꾹 누르면 자동 이동, 콤보/B2B/레벨.

signal active_changed
signal grid_changed
signal stats_changed
signal announce(text: String, big: bool)
signal cleared(rows: Array, label: String, points: int)
signal hard_dropped(cells: Array)
signal game_over

const COLS := 10
const ROWS := 22
const HIDDEN := 2
const DAS := 0.15
const ARR := 0.04
const LOCK_DELAY := 0.5
const MAX_RESETS := 15

const LINE_SCORE := [0, 100, 300, 500, 800]
const TSPIN_SCORE := [400, 800, 1200, 1600]
const SPIN_SCORE := [200, 400, 800, 1200]

var grid: Array = [] # ROWS x COLS, 0=빈칸 else 색인덱스
var bag: Array = []
var queue: Array = [] # 미리보기용 타입 문자열
var active_type := ""
var active_rot := 0
var active_pos := Vector2i.ZERO
var hold_type := ""
var can_hold := true
var score := 0
var level := 1
var lines := 0
var combo := -1
var b2b := false
var over := false
var paused := false
var last_rotate := false

var _fall_acc := 0.0
var _lock_acc := 0.0
var _resets := 0
var _das_dir := 0
var _das_time := 0.0
var _arr_time := 0.0
var _testing := false

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	grid.clear()
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append(0)
		grid.append(row)

func new_game() -> void:
	_init_grid()
	bag.clear()
	queue.clear()
	hold_type = ""
	can_hold = true
	score = 0
	level = 1
	lines = 0
	combo = -1
	b2b = false
	over = false
	paused = false
	_refill_queue()
	_spawn()
	emit_signal("grid_changed")
	emit_signal("active_changed")
	emit_signal("stats_changed")

# ---------- 진행 ----------

func _process(delta: float) -> void:
	if over or paused or _testing:
		return
	if active_type == "":
		return
	_update_das(delta)
	var interval := gravity_interval()
	if Input.is_action_pressed("soft_drop"):
		interval = minf(interval / 20.0, 0.025)
	_fall_acc += delta
	while _fall_acc >= interval and active_type != "" and not over:
		_fall_acc -= interval
		if not _step_down(Input.is_action_pressed("soft_drop")):
			break
	# 락딜레이
	if _on_ground():
		_lock_acc += delta
		if _lock_acc >= LOCK_DELAY:
			lock_piece(false)
	else:
		_lock_acc = 0.0
		_resets = 0

func gravity_interval() -> float:
	return maxf(0.02, 0.8 * pow(0.85, float(level - 1)))

func _update_das(delta: float) -> void:
	var l := Input.is_action_pressed("move_left")
	var r := Input.is_action_pressed("move_right")
	var dir := 0
	if l and not r:
		dir = -1
	elif r and not l:
		dir = 1
	elif l and r:
		dir = _das_dir if _das_dir != 0 else 1
	if dir != _das_dir:
		_das_dir = dir
		_das_time = 0.0
		_arr_time = 0.0
		if dir != 0:
			try_move(dir)
		return
	if dir == 0:
		return
	_das_time += delta
	if _das_time >= DAS:
		_arr_time += delta
		while _arr_time >= ARR:
			_arr_time -= ARR
			if not try_move(dir):
				_arr_time = 0.0
				break

func _input(event: InputEvent) -> void:
	if over or paused or _testing:
		return
	if event.is_action_pressed("rot_ccw"):
		try_rotate(false)
	elif event.is_action_pressed("rot_cw"):
		try_rotate(true)
	elif event.is_action_pressed("rot_180"):
		try_rotate_180()
	elif event.is_action_pressed("hard_drop"):
		hard_drop()
	elif event.is_action_pressed("hold_piece"):
		hold()

# ---------- 조작 ----------

func active_cells(pos: Vector2i = Vector2i(-999, -999), rot: int = -999) -> Array:
	if active_type == "":
		return []
	var p: Vector2i = active_pos if pos.x == -999 else pos
	var r: int = active_rot if rot == -999 else rot
	var out: Array = []
	for c in TetrisPieces.cells_for(active_type, r):
		out.append(p + c)
	return out

func fits(cells: Array) -> bool:
	for c in cells:
		var v: Vector2i = c
		if v.x < 0 or v.x >= COLS or v.y < 0 or v.y >= ROWS:
			return false
		if (grid[v.y] as Array)[v.x] != 0:
			return false
	return true

func try_move(dir: int) -> bool:
	if active_type == "":
		return false
	var cells: Array = []
	for c in active_cells():
		cells.append(c + Vector2i(dir, 0))
	if fits(cells):
		active_pos.x += dir
		last_rotate = false
		_ground_reset()
		_sfx("move")
		emit_signal("active_changed")
		return true
	return false

func try_rotate(cw: bool) -> bool:
	if active_type == "":
		return false
	var to_rot := posmod(active_rot + (1 if cw else -1), 4)
	var base: Array = TetrisPieces.cells_for(active_type, to_rot)
	for k in TetrisPieces.kicks_for(active_type, active_rot, to_rot):
		var cells: Array = []
		for c in base:
			cells.append(active_pos + c + k)
		if fits(cells):
			active_pos += k
			active_rot = to_rot
			last_rotate = true
			_ground_reset()
			_sfx("rotate")
			emit_signal("active_changed")
			return true
	return false

func try_rotate_180() -> bool:
	if active_type == "":
		return false
	var to_rot := posmod(active_rot + 2, 4)
	var base: Array = TetrisPieces.cells_for(active_type, to_rot)
	for k in TetrisPieces.kicks_for(active_type, active_rot, to_rot):
		var cells: Array = []
		for c in base:
			cells.append(active_pos + c + k)
		if fits(cells):
			active_pos += k
			active_rot = to_rot
			last_rotate = true
			_ground_reset()
			_sfx("rotate")
			emit_signal("active_changed")
			return true
	return false

func _step_down(scored: bool) -> bool:
	var cells: Array = []
	for c in active_cells():
		cells.append(c + Vector2i(0, 1))
	if fits(cells):
		active_pos.y += 1
		if scored:
			score += 1
			emit_signal("stats_changed")
		emit_signal("active_changed")
		return true
	_lock_acc += 0.001
	return false

func _on_ground() -> bool:
	if active_type == "":
		return false
	for c in active_cells():
		var below: Vector2i = c + Vector2i(0, 1)
		if below.y >= ROWS or (grid[below.y] as Array)[below.x] != 0:
			return true
	return false

func _ground_reset() -> void:
	if _on_ground() and _resets < MAX_RESETS:
		_resets += 1
		_lock_acc = 0.0

func ghost_cells() -> Array:
	var cells := active_cells()
	while true:
		var down: Array = []
		for c in cells:
			down.append(c + Vector2i(0, 1))
		if fits(down):
			cells = down
		else:
			break
	return cells

func hard_drop() -> void:
	if active_type == "" or over:
		return
	var cells := ghost_cells()
	var dist := 0
	if cells.size() > 0:
		dist = (cells[0] as Vector2i).y - (active_cells()[0] as Vector2i).y
	active_pos.y += dist
	score += dist * 2
	emit_signal("hard_dropped", cells)
	_sfx("hard")
	lock_piece(true)

func hold() -> void:
	if active_type == "" or not can_hold:
		return
	_sfx("hold")
	can_hold = false
	if hold_type == "":
		hold_type = active_type
		_spawn()
	else:
		var t := hold_type
		hold_type = active_type
		_spawn_specific(t)
	emit_signal("stats_changed")

func lock_piece(from_hard: bool) -> void:
	if active_type == "":
		return
	var spin_piece := _detect_spin()
	var cells := active_cells()
	var color: int = TetrisPieces.COLOR_INDEX[active_type]
	var all_hidden := true
	for c in cells:
		var v: Vector2i = c
		(grid[v.y] as Array)[v.x] = color
		if v.y >= HIDDEN:
			all_hidden = false
	active_type = ""
	_lock_acc = 0.0
	_resets = 0
	_fall_acc = 0.0
	if not from_hard:
		_sfx("lock")
	emit_signal("grid_changed")
	if all_hidden:
		_game_over()
		return
	_eval_clear(spin_piece)
	if over:
		return
	can_hold = true
	_spawn()
	if active_type != "" and not fits(active_cells()):
		_game_over()

func _detect_spin() -> String:
	## "" = 노스핀. O는 회전이 노옵이라 제외.
	if active_type == "" or active_type == "O" or not last_rotate:
		return ""
	if active_type == "T":
		return "T" if _is_tspin() else ""
	return active_type if _is_immobile() else ""

func _is_immobile() -> bool:
	## 좌/우/하 모두 막힘 (락 직전 빈 보드 기준).
	var cells := active_cells()
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var moved: Array = []
		for c in cells:
			moved.append(c + off)
		if fits(moved):
			return false
	return true

func _is_tspin() -> bool:
	if active_type != "T" or not last_rotate:
		return false
	var p := active_pos
	var n := 0
	for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var v: Vector2i = p + d
		if v.x < 0 or v.x >= COLS or v.y < 0 or v.y >= ROWS:
			n += 1
		elif (grid[v.y] as Array)[v.x] != 0:
			n += 1
	return n >= 3

func _eval_clear(spin: String) -> void:
	var full: Array = []
	for r in ROWS:
		var ok := true
		for c in COLS:
			if (grid[r] as Array)[c] == 0:
				ok = false
				break
		if ok:
			full.append(r)
	var n := full.size()
	var tspin := spin == "T"
	var any_spin := spin != ""
	var prefix := ("T-SPIN" if tspin else spin + "-SPIN") if any_spin else ""
	if n == 0:
		if any_spin:
			# 스핀 노라인도 점수+콤보 유지
			combo += 1
			var b0: int = TSPIN_SCORE[0] if tspin else SPIN_SCORE[0]
			var pts0 := b0 * level
			if b2b:
				pts0 = int(pts0 * 1.5)
			b2b = true
			score += pts0
			_sfx("tspin")
			emit_signal("announce", prefix + "!", true)
			emit_signal("cleared", [], prefix, pts0)
		else:
			combo = -1
		emit_signal("stats_changed")
		return
	full.sort()
	for i in range(full.size() - 1, -1, -1):
		grid.remove_at(full[i])
	for i in n:
		var row: Array = []
		for c in COLS:
			row.append(0)
		grid.push_front(row)
	lines += n
	var label := ""
	var pts := 0
	var difficult := n == 4 or any_spin
	if any_spin:
		var table: Array = TSPIN_SCORE if tspin else SPIN_SCORE
		pts = int(table[mini(n, 3)]) * level
		label = prefix + " " + (["", "SINGLE", "DOUBLE", "TRIPLE"][mini(n, 3)] if n > 0 else "")
	else:
		pts = LINE_SCORE[n] * level
		label = ["", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS!"][mini(n, 4)]
	if b2b and difficult:
		pts = int(pts * 1.5)
	if difficult:
		b2b = true
	elif n > 0:
		b2b = false
	combo += 1
	if combo > 0:
		pts += 50 * combo * level
		_sfx("combo")
	score += pts
	var new_level := lines / 10 + 1
	if new_level > level:
		level = new_level
		_sfx("level")
		emit_signal("announce", "LEVEL %d" % level, false)
	if any_spin:
		_sfx("tspin")
	elif n == 4:
		_sfx("tetris")
	else:
		_sfx("clear%d" % mini(n, 3))
	if n == 4 or any_spin:
		emit_signal("announce", label.strip_edges(), true)
	emit_signal("cleared", full, label, pts)
	emit_signal("grid_changed")
	emit_signal("stats_changed")

# ---------- 스폰 ----------

func _refill_bag() -> void:
	bag = TetrisPieces.ORDER.duplicate()
	bag.shuffle()

func _refill_queue() -> void:
	while queue.size() < 7:
		if bag.is_empty():
			_refill_bag()
		queue.append(bag.pop_back())

func _spawn() -> void:
	_refill_queue()
	_spawn_specific(String(queue.pop_front()))

func _spawn_specific(t: String) -> void:
	active_type = t
	active_rot = 0
	active_pos = Vector2i(4, 1)
	last_rotate = false
	_lock_acc = 0.0
	_resets = 0
	_fall_acc = 0.0
	_das_dir = 0
	emit_signal("active_changed")

func _game_over() -> void:
	over = true
	active_type = ""
	_sfx("over")
	emit_signal("game_over")

func _sfx(name: String) -> void:
	if _testing:
		return
	Sfx.play(name)

# ---------- 셀프 테스트 (--autotest) ----------

func run_self_test() -> String:
	_testing = true
	var fails: Array = []
	# 1. 회전 왕복 (4x CW/CCW = 원점)
	for t in TetrisPieces.ORDER:
		var c0: Array = TetrisPieces.cells_for(t, 0)
		if _sorted(TetrisPieces.cells_for(t, 4)) != _sorted(c0):
			fails.append("rot4:" + t)
	# 2. 7-bag 고유성
	_refill_bag()
	var s := {}
	for b in bag:
		s[b] = true
	if s.size() != 7:
		fails.append("bag")
	# 3. 라인 클리어 검출
	new_game()
	_testing = true
	for c in COLS:
		(grid[ROWS - 1] as Array)[c] = 1
	(grid[ROWS - 2] as Array)[0] = 1
	_eval_clear("")
	if lines != 1 or (grid[ROWS - 1] as Array)[0] != 1:
		fails.append("clear lines=%d" % lines)
	# 4. T스핀 검출 (T를 슬롯에 끼우고 코너 3개 점유)
	new_game()
	_testing = true
	# 바닥 20행: x 4,5,6 채움 / 19행: x 4,6 채움(측벽) / 17행 x4 채움(오버행)
	# → T 피벗(5,18) 코너 (4,17),(4,19),(6,19) 3점유
	for x in [4, 5, 6]:
		(grid[20] as Array)[x] = 2
	for x in [4, 6]:
		(grid[19] as Array)[x] = 2
	(grid[17] as Array)[4] = 2
	active_type = "T"
	active_rot = 0
	active_pos = Vector2i(5, 18)
	last_rotate = true
	if not _is_tspin():
		fails.append("tspin")
	# 5. 홀드 교환
	new_game()
	_testing = true
	var first := active_type
	hold()
	if hold_type != first or not can_hold == false:
		fails.append("hold1")
	var cur := active_type
	hold() # 락 전 2회째는 무시되어야 함
	if active_type != cur:
		fails.append("hold2")
	# 6. 하드드롭 점수+고정
	new_game()
	_testing = true
	var s0 := score
	hard_drop()
	if score <= s0 or active_type == "":
		fails.append("harddrop")
	# 7. T스핀 트리플 풀파이프라인 (검출+3줄+1600점)
	new_game()
	_testing = true
	for r in [19, 20, 21]:
		for c in COLS:
			(grid[r] as Array)[c] = 4
	for x in [4, 6]:
		(grid[18] as Array)[x] = 4
	(grid[17] as Array)[4] = 4
	(grid[16] as Array)[4] = 4
	active_type = "T"
	active_rot = 1
	active_pos = Vector2i(5, 17)
	last_rotate = true
	var s_before := score
	var l_before := lines
	lock_piece(false)
	if lines != l_before + 3:
		fails.append("tst-lines=%d" % lines)
	if score != s_before + 1600:
		fails.append("tst-score=%d" % (score - s_before))
	if grid.size() != ROWS:
		fails.append("tst-gridsize=%d" % grid.size())
	for r in ROWS:
		var full_row := true
		for c in COLS:
			if (grid[r] as Array)[c] == 0:
				full_row = false
				break
		if full_row:
			fails.append("tst-leftover=%d" % r)
			break
	# 8. 킥 회전 진입 ((0,0) 실패 → (-1,0) 킥 성공)
	new_game()
	_testing = true
	(grid[17] as Array)[5] = 4
	active_type = "T"
	active_rot = 0
	active_pos = Vector2i(5, 18)
	last_rotate = false
	if not try_rotate(true):
		fails.append("kick-fail")
	elif active_pos != Vector2i(4, 18):
		fails.append("kick-pos=%s" % str(active_pos))
	elif not last_rotate:
		fails.append("kick-flag")
	# 9. 게임오버 (스폰 막힘 → 블록아웃)
	new_game()
	_testing = true
	for c in COLS:
		(grid[1] as Array)[c] = 3
		(grid[2] as Array)[c] = 3
	_spawn()
	if not fits(active_cells()):
		_game_over()
	if not over:
		fails.append("over-not-detected")
	# 10. 180 킥 진입 (0→2, (0,0) 실패 → (0,-1) 성공)
	new_game()
	_testing = true
	(grid[19] as Array)[5] = 4
	active_type = "T"
	active_rot = 0
	active_pos = Vector2i(5, 18)
	last_rotate = false
	if not try_rotate_180():
		fails.append("r180-fail")
	elif active_rot != 2 or active_pos != Vector2i(5, 17):
		fails.append("r180-pos=%d,%s" % [active_rot, str(active_pos)])
	elif not last_rotate:
		fails.append("r180-flag")
	# 11. S스핀 싱글 (immobile + 1줄 = +400)
	new_game()
	_testing = true
	for c in COLS:
		if c != 0 and c != 4 and c != 5:
			(grid[19] as Array)[c] = 4
	for c in COLS:
		if c != 3 and c != 4:
			(grid[20] as Array)[c] = 4
	(grid[21] as Array)[3] = 4
	(grid[21] as Array)[4] = 4
	active_type = "S"
	active_rot = 0
	active_pos = Vector2i(4, 20)
	last_rotate = true
	var s10 := score
	var l10 := lines
	lock_piece(false)
	if lines != l10 + 1:
		fails.append("sspin-lines=%d" % lines)
	if score != s10 + 400:
		fails.append("sspin-score=%d" % (score - s10))
	# 12. Z스핀 노라인 (+200, 라인 유지)
	new_game()
	_testing = true
	for c in COLS:
		if c != 0 and c != 4 and c != 5:
			(grid[19] as Array)[c] = 4
	for c in COLS:
		if c != 5 and c != 6 and c != 9:
			(grid[20] as Array)[c] = 4
	(grid[21] as Array)[5] = 4
	(grid[21] as Array)[6] = 4
	active_type = "Z"
	active_rot = 0
	active_pos = Vector2i(5, 20)
	last_rotate = true
	var s11 := score
	var l11 := lines
	lock_piece(false)
	if lines != l11:
		fails.append("zspin-lines=%d" % lines)
	if score != s11 + 200:
		fails.append("zspin-score=%d" % (score - s11))
	# 13. O는 스핀 제외 (회전 후 락도 일반 싱글 +100)
	new_game()
	_testing = true
	for c in COLS:
		if c != 4 and c != 5:
			(grid[21] as Array)[c] = 4
	active_type = "O"
	active_rot = 0
	active_pos = Vector2i(4, 20)
	last_rotate = true
	var s12 := score
	lock_piece(false)
	if score != s12 + 100:
		fails.append("ospin-score=%d" % (score - s12))
	_testing = false
	if fails.is_empty():
		return "PASS"
	return "FAIL:" + ",".join(fails)

func _sorted(cells: Array) -> Array:
	var a := cells.duplicate()
	a.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return p.y < q.y or (p.y == q.y and p.x < q.x))
	return a
