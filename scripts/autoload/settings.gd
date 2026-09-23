extends Node
## 전역 설정 오토로드: 마우스 감도, 오디오 볼륨, 플랫폼(PC/모바일)
## user://settings.cfg 에 저장됨.

signal settings_changed

var mouse_sensitivity: float = 1.0 : set = set_mouse_sensitivity
var master_volume: float = 0.9
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var platform: String = "pc" # "pc" | "mobile"

const SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply_volumes()

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus(1)
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)

func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, 0.1, 3.0)
	emit_signal("settings_changed")

func mouse_factor() -> float:
	return 0.0022 * mouse_sensitivity

func apply_volumes() -> void:
	var master_db := linear_to_db(maxf(master_volume, 0.0001))
	AudioServer.set_bus_volume_db(0, master_db)
	var mi := AudioServer.get_bus_index("Music")
	if mi != -1:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music_volume, 0.0001)))
	var si := AudioServer.get_bus_index("SFX")
	if si != -1:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx_volume, 0.0001)))
	emit_signal("settings_changed")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("controls", "mouse_sensitivity", 1.0))
	master_volume = float(cfg.get_value("audio", "master", 0.9))
	music_volume = float(cfg.get_value("audio", "music", 0.8))
	sfx_volume = float(cfg.get_value("audio", "sfx", 0.9))
	platform = str(cfg.get_value("platform", "mode", "pc"))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("platform", "mode", platform)
	cfg.save(SAVE_PATH)

func is_mobile() -> bool:
	if platform == "mobile":
		return true
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return DisplayServer.is_touchscreen_available() and OS.has_feature("windows") == false
