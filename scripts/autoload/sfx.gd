extends Node
## 절차적 8비트 SFX 오토로드. 외부 파일 없이 AudioStreamWAV 합성.

var _pool: Array[AudioStreamPlayer] = []
var _bank := {}
const RATE := 22050

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_bank["move"] = _tone(220.0, 0.035)
	_bank["rotate"] = _tone(360.0, 0.045)
	_bank["hold"] = _sweep(520.0, 260.0, 0.09)
	_bank["lock"] = _tone(150.0, 0.05)
	_bank["hard"] = _noise_hit(0.09)
	_bank["clear1"] = _arp([523.0, 659.0], 0.05)
	_bank["clear2"] = _arp([523.0, 659.0, 784.0], 0.05)
	_bank["clear3"] = _arp([523.0, 659.0, 784.0, 1046.0], 0.05)
	_bank["tetris"] = _arp([523.0, 659.0, 784.0, 1046.0, 1318.0, 1568.0], 0.06)
	_bank["tspin"] = _sweep(300.0, 900.0, 0.16)
	_bank["combo"] = _arp([660.0, 880.0], 0.04)
	_bank["level"] = _arp([440.0, 554.0, 659.0, 880.0], 0.06)
	_bank["over"] = _arp([392.0, 330.0, 262.0, 196.0], 0.12)
	_bank["pause"] = _tone(440.0, 0.06)

func play(name: String, vol: float = 1.0) -> void:
	if not _bank.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _bank[name]
			p.volume_db = linear_to_db(maxf(vol, 0.001))
			p.play()
			return
	_pool[0].stream = _bank[name]
	_pool[0].play()

func _square(phase: float) -> float:
	return 1.0 if sin(phase) >= 0.0 else -1.0

func _tone(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-6.0 * t / dur)
		var v := _square(TAU * freq * t) * env
		data[i] = int(clampf(128.0 + v * 90.0, 0.0, 255.0))
	return _wav(data)

func _sweep(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		phase += TAU * f / RATE
		var env := exp(-4.0 * k)
		data[i] = int(clampf(128.0 + _square(phase) * env * 90.0, 0.0, 255.0))
	return _wav(data)

func _arp(freqs: Array, note_dur: float) -> AudioStreamWAV:
	var per := int(RATE * note_dur)
	var data := PackedByteArray()
	data.resize(per * freqs.size())
	var idx := 0
	for f in freqs:
		for i in per:
			var t := float(i) / RATE
			var env := exp(-5.0 * t / note_dur)
			data[idx] = int(clampf(128.0 + _square(TAU * float(f) * t) * env * 85.0, 0.0, 255.0))
			idx += 1
	return _wav(data)

func _noise_hit(dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var k := float(i) / n
		var env := exp(-9.0 * k)
		var v := (randf() * 2.0 - 1.0) * env
		data[i] = int(clampf(128.0 + v * 110.0, 0.0, 255.0))
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
