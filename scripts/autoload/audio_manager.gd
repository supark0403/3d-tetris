extends Node
## UI 효과음 오토로드. Wooden UI SFX Pack(assets/sfx) 사용.

var _players: Array[AudioStreamPlayer] = []
const BUS := "SFX"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)

func _play(path: String, vol: float = 1.0) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(maxf(vol, 0.0001))
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()

func click() -> void:
	_play("res://assets/sfx/Mono/ogg/JDSherbert - Wooden UI SFX Pack - Confirm - 1.ogg", 0.9)

func hover() -> void:
	_play("res://assets/sfx/Mono/ogg/JDSherbert - Wooden UI SFX Pack - Cursor - 1.ogg", 0.5)

func cancel() -> void:
	_play("res://assets/sfx/Mono/ogg/JDSherbert - Wooden UI SFX Pack - Cancel - 1.ogg", 0.9)

func error() -> void:
	_play("res://assets/sfx/Mono/ogg/JDSherbert - Wooden UI SFX Pack - Error - 1.ogg", 0.9)
