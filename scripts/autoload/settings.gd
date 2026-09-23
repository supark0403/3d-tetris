extends Node
## 볼륨 설정 오토로드 (user://tetris_settings.cfg 저장).

var master_volume := 0.9
var sfx_volume := 0.9

const PATH := "user://tetris_settings.cfg"

func _ready() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")
	load_settings()
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var i := AudioServer.get_bus_index("SFX")
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(sfx_volume, 0.0001)))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", 0.9)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 0.9)), 0.0, 1.0)
