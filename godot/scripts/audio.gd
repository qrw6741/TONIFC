extends Node
## AUDIO — all music and sound effects are synthesized at startup (no audio files).

const RATE := 22050
var sfx = {}
var pool = []
var music: AudioStreamPlayer
var crowd: AudioStreamPlayer
var _crowd_target = 0.0

func _ready() -> void:
	for i in 10:
		var p = AudioStreamPlayer.new(); add_child(p); pool.append(p)
	music = AudioStreamPlayer.new(); add_child(music)
	crowd = AudioStreamPlayer.new(); add_child(crowd)
	_build_sfx()
	crowd.stream = _wav(_crowd_loop(), true)
	music.stream = _wav(_music_loop(), true)

# ---------------- synthesis helpers ----------------
func _buf(dur: float) -> PackedFloat32Array:
	var b = PackedFloat32Array(); b.resize(int(dur * RATE)); return b

func _env(i: int, n: int, attack: float) -> float:
	var t = float(i) / RATE
	var a: float = min(1.0, t / max(attack, 0.001))
	return a * pow(1.0 - float(i) / n, 2.0)

func _tone(b: PackedFloat32Array, start: float, freq: float, dur: float, vol := 0.3, type := "sine", slide := 1.0, attack := 0.005) -> void:
	var s0 = int(start * RATE); var n = int(dur * RATE); var ph = 0.0
	for i in n:
		if s0 + i >= b.size(): break
		var f = freq * pow(slide, float(i) / n)
		ph += f / RATE
		var x = 0.0
		match type:
			"sine": x = sin(ph * TAU)
			"square": x = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw": x = fmod(ph, 1.0) * 2.0 - 1.0
			"tri": x = abs(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
		b[s0 + i] += x * vol * _env(i, n, attack)

func _noise(b: PackedFloat32Array, start: float, dur: float, vol := 0.3, cutoff := 1200.0, attack := 0.005, highpass := false) -> void:
	var s0 = int(start * RATE); var n = int(dur * RATE); var lp = 0.0
	var a: float = clamp(cutoff / RATE * TAU, 0.001, 1.0)
	for i in n:
		if s0 + i >= b.size(): break
		var w = randf() * 2.0 - 1.0
		lp += (w - lp) * a
		var x = (w - lp) if highpass else lp * 2.0
		b[s0 + i] += x * vol * _env(i, n, attack)

func _wav(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false
	var bytes = PackedByteArray(); bytes.resize(b.size() * 2)
	for i in b.size(): bytes.encode_s16(i * 2, int(clamp(b[i], -1.0, 1.0) * 32000))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = b.size()
	return w

func _build_sfx() -> void:
	var b: PackedFloat32Array
	b = _buf(0.06); _tone(b, 0, 1800, 0.05, 0.12, "tri"); sfx.move = _wav(b)
	b = _buf(0.2); _tone(b, 0, 880, 0.08, 0.3, "tri"); _tone(b, 0.05, 1320, 0.12, 0.25, "tri"); sfx.select = _wav(b)
	b = _buf(0.12); _tone(b, 0, 660, 0.1, 0.25, "tri", 0.6); sfx.back = _wav(b)
	b = _buf(0.3); _tone(b, 0, 200, 0.18, 0.12, "square"); _tone(b, 0.09, 150, 0.2, 0.12, "square"); sfx.error = _wav(b)
	b = _buf(0.3); _tone(b, 0, 1568, 0.08, 0.1, "square"); _tone(b, 0.07, 2093, 0.18, 0.1, "square"); sfx.coin = _wav(b)
	b = _buf(0.7); _noise(b, 0, 0.6, 0.5, 2500, 0.2); sfx.whoosh = _wav(b)
	b = _buf(0.15); _noise(b, 0, 0.12, 0.25, 6000, 0.005, true); sfx.tab = _wav(b)
	b = _buf(1.3); _tone(b, 0, 70, 1.2, 0.9, "sine", 0.4); _noise(b, 0, 0.8, 0.5, 300); sfx.boom = _wav(b)
	b = _buf(1.7); _noise(b, 0, 1.6, 0.35, 1800, 1.4); _tone(b, 0, 220, 1.6, 0.08, "saw", 4.0, 1.4); sfx.riser = _wav(b)
	b = _buf(0.8)
	for i in 4: _tone(b, i * 0.07, [523, 659, 784, 1047][i], 0.5, 0.2, "tri")
	sfx.reveal = _wav(b)
	b = _buf(1.6)
	for i in 6: _tone(b, i * 0.06, [392, 523, 659, 784, 1047, 1319][i], 0.9, 0.09, "saw")
	_tone(b, 0, 70, 1.2, 0.8, "sine", 0.4); sfx.bigreveal = _wav(b)
	b = _buf(0.4); _tone(b, 0, 2900, 0.35, 0.25); _tone(b, 0, 3050, 0.35, 0.15); sfx.whistle = _wav(b)
	b = _buf(1.8)
	for w in [0.0, 0.45, 0.9]: _tone(b, w, 2900, 0.8 if w > 0.8 else 0.3, 0.25)
	sfx.whistle3 = _wav(b)
	b = _buf(0.12); _noise(b, 0, 0.08, 0.5, 1500); _tone(b, 0, 120, 0.08, 0.4, "sine", 0.5); sfx.kick = _wav(b)
	b = _buf(0.6); _tone(b, 0, 1200, 0.5, 0.3, "tri"); _tone(b, 0, 1800, 0.4, 0.12); sfx.post = _wav(b)
	b = _buf(0.5); _noise(b, 0, 0.4, 0.4, 600); sfx.net = _wav(b)
	b = _buf(0.2); _noise(b, 0, 0.15, 0.4, 500); sfx.tackle = _wav(b)
	b = _buf(3.6); _noise(b, 0, 3.5, 0.9, 1100, 0.15); sfx.goalcrowd = _wav(b)
	b = _buf(1.5); _noise(b, 0, 1.4, 0.5, 800, 0.2); sfx.ooh = _wav(b)

func _crowd_loop() -> PackedFloat32Array:
	var b = _buf(3.0); var lp = 0.0; var lp2 = 0.0
	for i in b.size():
		var w = randf() * 2.0 - 1.0
		lp += (w - lp) * 0.18; lp2 += (lp - lp2) * 0.5
		b[i] = (lp - lp2 * 0.6) * 0.9
	# crossfade ends for a seamless loop
	var f = 2000
	for i in f:
		var k = float(i) / f
		b[i] = b[i] * k + b[b.size() - f + i] * (1.0 - k)
	return b

## 4-bar synth loop: pad chords, pulse bass, kick, snare & hats at 120bpm
func _music_loop() -> PackedFloat32Array:
	var step = 0.125
	var b = _buf(64 * step + 0.01)
	var chords = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [55, 59, 62, 66]]
	var mtof = func(m: int) -> float: return 440.0 * pow(2.0, (m - 69) / 12.0)
	for st in 64:
		var t = st * step; var bar = st / 16; var s16 = st % 16; var ch: Array = chords[bar]
		if s16 == 0:
			for nn in ch: _tone(b, t, mtof.call(nn), 2.0, 0.045, "saw", 1.0, 0.25)
		if s16 % 2 == 0: _tone(b, t, mtof.call(ch[0] - 24), 0.2, 0.32 if s16 % 4 == 0 else 0.2, "tri")
		if s16 % 4 == 0: _tone(b, t, 55, 0.25, 0.55, "sine", 0.5)
		if s16 % 8 == 4: _noise(b, t, 0.18, 0.25, 2500)
		if s16 % 2 == 1: _noise(b, t, 0.04, 0.12, 7000, 0.002, true)
		if s16 % 2 == 0 and bar % 2 == 1:
			var arp = [0, 2, 1, 3, 2, 1, 3, 0]
			_tone(b, t, mtof.call(ch[arp[(s16 / 2) % 8]] + 12), 0.18, 0.04, "square")
	return b

# ---------------- playback ----------------
func settings() -> Dictionary:
	return Save.data.settings if Save.data else Save.default_settings()

func play(name: String) -> void:
	if not sfx.has(name): return
	for p in pool:
		if not p.playing:
			p.stream = sfx[name]
			p.volume_db = linear_to_db(max(0.0001, settings().sfx * 0.8))
			p.play(); return

func music_on() -> void:
	music.volume_db = linear_to_db(max(0.0001, settings().music * 0.55))
	if not music.playing: music.play()
func music_off() -> void: music.stop()
func apply_volumes() -> void:
	music.volume_db = linear_to_db(max(0.0001, settings().music * 0.55))

func crowd_on() -> void:
	crowd.volume_db = -40; crowd.play(); _crowd_target = 0.3
func crowd_off() -> void: crowd.stop(); _crowd_target = 0
func crowd_level(x: float) -> void: _crowd_target = x
func _process(delta: float) -> void:
	if crowd.playing:
		var target = linear_to_db(max(0.0001, _crowd_target * settings().crowd * 0.9))
		crowd.volume_db = lerp(crowd.volume_db, target, min(1.0, delta * 2.0))
