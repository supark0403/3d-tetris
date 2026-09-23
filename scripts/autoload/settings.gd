extends Node
## 볼륨 설정 오토로드 (user://tetris_settings.cfg 저장).

var master_volume := 0.9
var sfx_volume := 0.9

const PATH := "user://tetris_settings.cfg"

const GAME_ACTIONS: Array[String] = ["move_left", "move_right", "soft_drop", "hard_drop", "rot_ccw", "rot_cw", "hold_piece"]
const ACTION_LABELS := {
	"move_left": "왼쪽 이동",
	"move_right": "오른쪽 이동",
	"soft_drop": "소프트드롭",
	"hard_drop": "하드드롭",
	"rot_ccw": "반시계 회전",
	"rot_cw": "시계 회전",
	"hold_piece": "홀드",
}
const DEFAULT_KEYS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"soft_drop": KEY_S,
	"hard_drop": KEY_W,
	"rot_ccw": KEY_LEFT,
	"rot_cw": KEY_RIGHT,
	"hold_piece": KEY_SPACE,
}
var bindings := {}

func _ready() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")
	load_settings()
	apply()
	apply_bindings()

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var i := AudioServer.get_bus_index("SFX")
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(sfx_volume, 0.0001)))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	for a in GAME_ACTIONS:
		cfg.set_value("keys", a, int(bindings.get(a, DEFAULT_KEYS[a])))
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_reset_bindings_silent()
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", 0.9)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 0.9)), 0.0, 1.0)
	for a in GAME_ACTIONS:
		bindings[a] = int(cfg.get_value("keys", a, DEFAULT_KEYS[a]))

func apply_bindings() -> void:
	for a in GAME_ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = int(bindings.get(a, DEFAULT_KEYS[a]))
		InputMap.action_add_event(a, ev)

func key_name(action: String) -> String:
	return OS.get_keycode_string(int(bindings.get(action, DEFAULT_KEYS[action])))

func reset_keys() -> void:
	_reset_bindings_silent()
	apply_bindings()
	save_settings()

func _reset_bindings_silent() -> void:
	for a in GAME_ACTIONS:
		bindings[a] = DEFAULT_KEYS[a]
