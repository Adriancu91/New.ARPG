extends Node
## Audio architecture: buses (Music, Ambience, SFX, UI), pooled SFX players,
## music + ambience loops. Every sound is a PLACEHOLDER synthesized at startup
## (original, copyright-free). Real recordings can replace any id by dropping
## res://audio/sfx/<id>.ogg|.wav (or audio/music/<id>.ogg) into the project.

const MIX_RATE := 22050
const POOL_SIZE := 12
const BUSES := ["Music", "Ambience", "SFX", "UI"]

var streams: Dictionary = {}
var _pool: Array = []
var _pool_idx := 0
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var volumes := {"Master": 0.8, "Music": 0.55, "Ambience": 0.6, "SFX": 0.8, "UI": 0.7}


func _ready() -> void:
	_rng.seed = 7
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "Ambience"
	add_child(ambience_player)
	_build_library()


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for b in volumes:
		set_volume(b, volumes[b])


func set_volume(bus: String, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volumes[bus], 0.0001)))


func play(id: String, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> void:
	var s: AudioStream = streams.get(id)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = s
	p.bus = "UI" if id.begins_with("ui_") else "SFX"
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func play_music(id: String) -> void:
	var s: AudioStream = streams.get(id)
	if s == null or (music_player.stream == s and music_player.playing):
		return
	music_player.stream = s
	music_player.play()


func play_ambience(id: String) -> void:
	var s: AudioStream = streams.get(id)
	if s == null or (ambience_player.stream == s and ambience_player.playing):
		return
	ambience_player.stream = s
	ambience_player.play()


func stop_music() -> void:
	music_player.stop()


# ---------------------------------------------------------------- library

func _build_library() -> void:
	# id: [generator, params...]
	streams["swing"] = _make(0.22, func(t, d): return _noise() * _env(t, 0.02, d) * 0.5 * (1.0 - t / d) + sin(TAU * lerpf(500.0, 180.0, t / d) * t) * 0.15 * _env(t, 0.01, d))
	streams["heavy_swing"] = _make(0.38, func(t, d): return _noise() * _env(t, 0.06, d) * 0.6 + sin(TAU * lerpf(220.0, 70.0, t / d) * t) * 0.3 * _env(t, 0.02, d))
	streams["hit"] = _make(0.16, func(t, d): return (_noise() * 0.7 + sin(TAU * 140.0 * t) * 0.6) * exp(-t * 28.0))
	streams["crit"] = _make(0.3, func(t, d): return (_noise() * 0.5 + sin(TAU * 880.0 * t) * 0.35 + sin(TAU * 110.0 * t) * 0.6) * exp(-t * 14.0))
	streams["player_hurt"] = _make(0.25, func(t, d): return (sin(TAU * lerpf(300.0, 120.0, t / d) * t) * 0.6 + _noise() * 0.3) * exp(-t * 10.0))
	streams["block"] = _make(0.2, func(t, d): return (sin(TAU * 1200.0 * t) * 0.3 + sin(TAU * 1730.0 * t) * 0.25 + _noise() * 0.2) * exp(-t * 18.0))
	streams["dodge"] = _make(0.25, func(t, d): return _noise() * _env(t, 0.05, d) * 0.45 * sin(PI * t / d))
	streams["spell_light"] = _make(0.6, func(t, d): return (sin(TAU * 660.0 * t) * 0.25 + sin(TAU * 990.0 * t) * 0.2 + sin(TAU * 1320.0 * t * (1.0 + t)) * 0.12) * _env(t, 0.03, d))
	streams["spell_fire"] = _make(0.55, func(t, d): return (_noise() * 0.55 + sin(TAU * 90.0 * t) * 0.3) * _env(t, 0.04, d))
	streams["spell_shadow"] = _make(0.6, func(t, d): return (sin(TAU * lerpf(160.0, 60.0, t / d) * t) * 0.5 + _noise() * 0.2) * _env(t, 0.05, d))
	streams["spell_frost"] = _make(0.5, func(t, d): return (sin(TAU * 1760.0 * t) * 0.15 + sin(TAU * 2349.0 * t) * 0.12 + _noise() * 0.25) * _env(t, 0.01, d))
	streams["spell_arcane"] = _make(0.45, func(t, d): return (sin(TAU * lerpf(400.0, 1200.0, t / d) * t) * 0.3 + sin(TAU * 600.0 * t) * 0.15) * _env(t, 0.02, d))
	streams["bow"] = _make(0.2, func(t, d): return (sin(TAU * 180.0 * t) * 0.4 * exp(-t * 20.0) + _noise() * 0.3 * exp(-t * 30.0)))
	streams["explosion"] = _make(0.8, func(t, d): return (_noise() * 0.8 + sin(TAU * 55.0 * t) * 0.6) * exp(-t * 5.0))
	streams["enemy_die"] = _make(0.45, func(t, d): return (sin(TAU * lerpf(240.0, 60.0, t / d) * t) * 0.45 + _noise() * 0.25) * _env(t, 0.02, d))
	streams["enemy_attack"] = _make(0.3, func(t, d): return (sin(TAU * lerpf(110.0, 80.0, t / d) * t) * 0.5 + _noise() * 0.2) * _env(t, 0.05, d))
	streams["boss_roar"] = _make(1.3, func(t, d): return (sin(TAU * (70.0 + 12.0 * sin(TAU * 6.0 * t)) * t) * 0.6 + _noise() * 0.35 + sin(TAU * 35.0 * t) * 0.4) * _env(t, 0.15, d))
	streams["slam"] = _make(0.7, func(t, d): return (_noise() * 0.6 + sin(TAU * 45.0 * t) * 0.9) * exp(-t * 6.0))
	streams["pickup"] = _make(0.18, func(t, d): return sin(TAU * (880.0 if t < 0.07 else 1318.0) * t) * 0.3 * _env(t, 0.005, d))
	streams["gold"] = _make(0.25, func(t, d): return (sin(TAU * 2093.0 * t) * 0.2 + sin(TAU * 2637.0 * t) * 0.15) * exp(-t * 14.0))
	streams["rare_drop"] = _make(0.9, func(t, d): return (sin(TAU * 523.0 * t) + sin(TAU * 659.0 * t) + sin(TAU * 784.0 * t) + sin(TAU * 1046.0 * t * (1.0 if t < 0.3 else 1.0))) * 0.09 * _env(t, 0.02, d))
	streams["level_up"] = _make(1.2, func(t, d): return (sin(TAU * [392.0, 523.0, 659.0, 784.0][mini(3, int(t / 0.18))] * t) * 0.3 + sin(TAU * 1046.0 * t) * 0.08) * _env(t, 0.01, d))
	streams["quest"] = _make(0.9, func(t, d): return (sin(TAU * (587.0 if t < 0.3 else 880.0) * t) * 0.28) * _env(t, 0.01, d))
	streams["potion"] = _make(0.4, func(t, d): return sin(TAU * lerpf(300.0, 900.0, t / d) * t) * 0.22 * _env(t, 0.02, d))
	streams["footstep"] = _make(0.09, func(t, d): return _noise() * 0.25 * exp(-t * 60.0))
	streams["chest"] = _make(0.6, func(t, d): return (sin(TAU * 140.0 * t) * 0.4 * exp(-t * 6.0) + _noise() * 0.2 * exp(-t * 12.0) + sin(TAU * 784.0 * t) * 0.12 * _env(t, 0.2, d)))
	streams["ui_click"] = _make(0.06, func(t, d): return sin(TAU * 1500.0 * t) * 0.25 * exp(-t * 60.0))
	streams["ui_open"] = _make(0.18, func(t, d): return (sin(TAU * lerpf(500.0, 900.0, t / d) * t) * 0.18) * _env(t, 0.01, d))
	streams["telegraph"] = _make(0.5, func(t, d): return sin(TAU * 220.0 * t) * 0.25 * sin(TAU * 8.0 * t) * _env(t, 0.05, d))
	streams["door"] = _make(1.0, func(t, d): return (_noise() * 0.25 + sin(TAU * 60.0 * t) * 0.4) * _env(t, 0.1, d))
	streams["music_vale"] = _make_loop(16.0, _music_vale)
	streams["music_reliquary"] = _make_loop(16.0, _music_reliquary)
	streams["music_boss"] = _make_loop(8.0, _music_boss)
	streams["ambience_wind"] = _make_loop(8.0, func(t, d): return _noise() * 0.12 * (0.6 + 0.4 * sin(TAU * t / d)))
	_load_overrides()


func _load_overrides() -> void:
	for id in streams.keys():
		for dir in ["res://audio/sfx/", "res://audio/music/"]:
			for ext in [".ogg", ".wav"]:
				var path: String = dir + id + ext
				if ResourceLoader.exists(path):
					streams[id] = load(path)


var _noise_state := 22222
func _noise() -> float:
	_noise_state = (_noise_state * 1103515245 + 12345) & 0x7fffffff
	return float(_noise_state) / float(0x3fffffff) - 1.0


static func _env(t: float, attack: float, dur: float) -> float:
	if t < attack:
		return t / attack
	return clampf(1.0 - (t - attack) / maxf(0.001, dur - attack), 0.0, 1.0)


func _make(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var v: float = clampf(gen.call(t, duration), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s


func _make_loop(duration: float, gen: Callable) -> AudioStreamWAV:
	var s := _make(duration, gen)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(duration * MIX_RATE)
	return s


# Slow modal drones. Period-aligned frequencies keep loops seamless.
func _music_vale(t: float, d: float) -> float:
	var f := 1.0 / d
	var chord := [55.0, 82.5, 110.0, 130.8]
	var v := 0.0
	for i in chord.size():
		var freq: float = roundf(chord[i] / f) * f
		v += sin(TAU * freq * t + sin(TAU * f * (i + 1) * t) * 0.8) * (0.14 - i * 0.02)
	var bell_t := fmod(t, 4.0)
	v += sin(TAU * 440.0 * t) * 0.05 * exp(-bell_t * 2.5)
	return v * (0.7 + 0.3 * sin(TAU * f * t))


func _music_reliquary(t: float, d: float) -> float:
	var f := 1.0 / d
	var v := sin(TAU * 41.25 * t) * 0.2 + sin(TAU * roundf(61.7 / f) * f * t) * 0.1 + sin(TAU * roundf(98.0 / f) * f * t + sin(TAU * f * 2.0 * t)) * 0.06
	var drip := fmod(t * 0.75, 1.0)
	v += sin(TAU * 1568.0 * t) * 0.03 * exp(-drip * 30.0)
	return v


func _music_boss(t: float, d: float) -> float:
	var beat := fmod(t, 0.5)
	var v := sin(TAU * 55.0 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.1
	v += sin(TAU * 50.0 * t) * 0.5 * exp(-beat * 14.0)
	v += _noise() * 0.12 * exp(-fmod(t + 0.25, 0.5) * 30.0)
	return v
