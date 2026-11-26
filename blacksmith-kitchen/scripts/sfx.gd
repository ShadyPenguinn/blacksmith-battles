class_name Sfx
extends RefCounted
## Little sound effects made from code (no audio files): clangs, puffs, sizzles, dings.

const RATE := 22050
static var _cache := {}
static var _players := []
static var _next := 0

static func _make(name: String) -> AudioStreamWAV:
	var data = PackedFloat32Array()
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"clang":
			data = _tone([820.0, 1290.0, 1960.0, 2750.0], 0.55, 7.0, rng, 0.25)
		"thud":
			data = _tone([70.0, 105.0], 0.35, 10.0, rng, 0.5)
		"puff":
			data = _noise(0.28, rng, 0.25, 6.0)
		"crack":
			data = _noise(0.12, rng, 0.9, 30.0)
		"sizzle":
			data = _noise(0.9, rng, 0.08, 2.5, true)
		"ding":
			data = _tone([1320.0, 2640.0], 0.6, 5.0, rng, 0.0)
		"tick":
			data = _tone([1800.0], 0.05, 60.0, rng, 0.4)
		"good":
			data = _melody([523.0, 659.0, 784.0], 0.09)
		"bad":
			data = _melody([392.0, 311.0], 0.16)
		"fanfare":
			data = _melody([523.0, 659.0, 784.0, 1046.0, 0.0, 784.0, 1046.0], 0.13)
	var pcm = PackedByteArray()
	pcm.resize(data.size() * 2)
	for i in data.size():
		pcm.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 30000.0))
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = pcm
	return s

static func _tone(freqs: Array, length: float, decay: float, rng: RandomNumberGenerator, noise: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	var n = int(length * RATE)
	out.resize(n)
	for i in n:
		var t = float(i) / RATE
		var v = 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) / (k + 1.0)
		var env = exp(-decay * t)
		var hit = noise * rng.randf_range(-1, 1) * exp(-60.0 * t)
		out[i] = (v * 0.35 * env + hit) * minf(1.0, t * 800.0)
	return out

static func _noise(length: float, rng: RandomNumberGenerator, smooth: float, decay: float, crackle := false) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	var n = int(length * RATE)
	out.resize(n)
	var y = 0.0
	for i in n:
		var t = float(i) / RATE
		y = lerpf(y, rng.randf_range(-1, 1), smooth)
		var env = exp(-decay * t) * minf(1.0, t * 200.0)
		if crackle and rng.randf() < 0.002:
			y += rng.randf_range(-0.8, 0.8)
		out[i] = y * env * (0.9 if smooth > 0.5 else 1.6)
	return out

static func _melody(notes: Array, step: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	for f in notes:
		var n = int(step * RATE)
		for i in n:
			var t = float(i) / RATE
			var v = 0.0 if f == 0.0 else (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * 0.3 * exp(-4.0 * t)
			out.append(v * minf(1.0, t * 400.0))
	return out

static func play(name: String, pitch := 1.0, volume_db := -4.0) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if not _cache.has(name):
		_cache[name] = _make(name)
	if _players.is_empty():
		for i in 10:
			var p = AudioStreamPlayer.new()
			tree.root.add_child.call_deferred(p)
			_players.append(p)
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	if not pl.is_inside_tree():
		return
	pl.stream = _cache[name]
	pl.pitch_scale = pitch * randf_range(0.95, 1.05)
	pl.volume_db = volume_db
	pl.play()
