extends Node
## Sfx autoload: tiny procedurally-generated sound effects (no assets needed).

var _players: Array[AudioStreamPlayer] = []
var _next := 0

const RATE := 22050


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _tone(freq: float, dur: float, vol := 0.25, slide := 0.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq + slide * t
		phase += TAU * f / RATE
		var env := 1.0 - float(i) / n
		s[i] = sin(phase) * env * vol
	return _wav(s)


func _noise(dur: float, vol := 0.2) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in n:
		s[i] = rng.randf_range(-1.0, 1.0) * (1.0 - float(i) / n) * vol
	return _wav(s)


func play(stream: AudioStream) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()


func eat() -> void:
	play(_tone(660.0, 0.09, 0.3, 300.0))


func great() -> void:
	play(_tone(523.0, 0.12, 0.25))
	get_tree().create_timer(0.08).timeout.connect(func(): play(_tone(784.0, 0.18, 0.25)))


func wrong() -> void:
	play(_tone(180.0, 0.25, 0.3, -60.0))


func over() -> void:
	play(_tone(392.0, 0.3, 0.25, -120.0))
	get_tree().create_timer(0.2).timeout.connect(func(): play(_tone(262.0, 0.4, 0.25, -80.0)))


func click() -> void:
	play(_tone(880.0, 0.05, 0.15))


func count_tick(final := false) -> void:
	play(_tone(440.0 if not final else 880.0, 0.12, 0.25))
