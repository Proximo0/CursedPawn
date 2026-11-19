class_name MusicPlayer
extends Node
## Plays the procedural music (MusicSynth). One track at a time, built lazily one stem per frame (so the single-threaded
## web build never stalls on a whole track), stems layered by intensity (the game's Dread over its wake threshold).
## Switching tracks cross-fades. Scripted runs (tests, captures) track state but build and play nothing.

const SILENT_DB: float = -80.0
const PREFETCH_ORDER: PackedStringArray = ["shop", "table", "collector", "title"]
const PREFETCH_GAP: int = 45
const START_DELAY: float = 2.0  ## no music building in the first seconds: boot and the first customer come first
const CALM_DELTA: float = 0.04
const BASE_DB: float = -2.0  ## the stems sit near -24 dBFS active (sfx at -21, stingers -17); this keeps music a little under
const DREAD_DIP_DB: float = 4.0  ## the music dips this far under the Dread shimmer at full intensity
const FADE_PER_SEC: float = 0.8  ## track fade, 0..1 per second
const LAYER_EASE: float = 0.5  ## layer fade, 0..1 per second
## Intensity at which each stem is fully in (it starts fading in 0.25 before): stem 0 is always on.
const LAYER_AT: PackedFloat32Array = [0.0, 0.5, 0.85]

var track: String = ""  ## wanted track ("" = none)
var master: float = 1.0
var muted: bool = false
var seed_value: int = 1
var build_ms: float = 0.0  ## total time building stems so far
var intensity: float = 0.0
var duck_db: float = 0.0  ## current ducking in dB (<= 0)

var _prefetch_wait: int = 0
var _age: float = 0.0  ## seconds since the node entered the tree
var _streams: Dictionary = {}  ## "track:stem" -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []  ## stems of the current track
var _fading: Array[AudioStreamPlayer] = []  ## stems of the previous track, fading out
var _cur: String = ""  ## track the players belong to
var _level: float = 0.0  ## current track fade 0..1
var _layer: PackedFloat32Array = [1.0, 0.0, 0.0]
var _duck_target: float = 0.0
var _duck_hold: float = 0.0
var _duck_release: float = 1.0


func _process(delta: float) -> void:
	var scripted: bool = Flags.is_scripted_run()
	_age += delta
	var calm: bool = _age >= START_DELAY and delta <= CALM_DELTA  ## a build is a hitch, so only on calm frames after boot
	if not scripted and track != _cur and calm:
		_switch()
	# Build at most one missing stem per frame for the current track.
	if not scripted and _cur != "" and calm:
		for s: int in range(MusicSynth.mu_stem_count(_cur)):
			if s >= _players.size() or _players[s].stream == null:
				_build_stem(s)
				break
	# Once the wanted track is fully built, build the other tracks' stems in the background, one per PREFETCH_GAP frames,
	# so a track change later (night start, the table, the Collector) does not stall a frame on a build.
	if _prefetch_wait > 0:
		_prefetch_wait -= 1
	elif not scripted and calm and _cur != "" and is_ready(_cur):
		_prefetch_one()
	# fades
	var want: float = 1.0 if (track != "" and not muted) else 0.0
	_level = move_toward(_level, want, FADE_PER_SEC * delta)
	for s: int in range(_layer.size()):
		var lo: float = LAYER_AT[s] - 0.25
		var target: float = 1.0 if s == 0 else clampf((intensity - lo) / 0.25, 0.0, 1.0)
		_layer[s] = move_toward(_layer[s], target, LAYER_EASE * delta)
	if _duck_hold > 0.0:
		_duck_hold -= delta
	else:
		_duck_target = 0.0
	duck_db = move_toward(duck_db, _duck_target, (60.0 if _duck_target < duck_db else 12.0 / _duck_release) * delta)
	_apply()
	var i: int = 0
	while i < _fading.size():
		var p: AudioStreamPlayer = _fading[i]
		p.volume_db = move_toward(p.volume_db, SILENT_DB, 60.0 * delta)
		if p.volume_db <= SILENT_DB + 1.0:
			p.stop()
			p.queue_free()
			_fading.remove_at(i)
		else:
			i += 1


func play_track(name: String) -> void:
	if name == "" or MusicSynth.TRACKS.has(name):
		track = name


func stop() -> void:
	track = ""


## 0..1: how many stems are heard (the game's Dread over its wake threshold).
func set_intensity(norm: float) -> void:
	intensity = clampf(norm, 0.0, 1.0)


## Dips the music by `db` (negative) for `hold` seconds, then eases back over `release` seconds. Attack is instant.
func duck(db: float, hold: float, release: float = 1.5) -> void:
	if db < _duck_target or _duck_hold <= 0.0:
		_duck_target = minf(db, 0.0)
	_duck_hold = maxf(_duck_hold, hold)
	_duck_release = maxf(release, 0.05)


func set_muted(on: bool) -> void:
	muted = on


func set_master_volume(v: float) -> void:
	master = clampf(v, 0.0, 1.0)


## Builds every stem of a track now (tools and tests); returns the milliseconds taken.
func build_all(name: String) -> float:
	var t0: float = build_ms
	for s: int in range(MusicSynth.mu_stem_count(name)):
		_stream(name, s)
	return build_ms - t0


func is_ready(name: String) -> bool:
	for s: int in range(MusicSynth.mu_stem_count(name)):
		if not _streams.has("%s:%d" % [name, s]):
			return false
	return MusicSynth.mu_stem_count(name) > 0


func _stream(name: String, s: int) -> AudioStreamWAV:
	var key: String = "%s:%d" % [name, s]
	if not _streams.has(key):
		var t0: int = Time.get_ticks_usec()
		_streams[key] = MusicSynth.build_stem(name, s, seed_value)
		build_ms += float(Time.get_ticks_usec() - t0) / 1000.0
	return _streams[key]


func _prefetch_one() -> void:
	for name: String in PREFETCH_ORDER:
		for st: int in range(MusicSynth.mu_stem_count(name)):
			if not _streams.has("%s:%d" % [name, st]):
				_stream(name, st)
				_prefetch_wait = PREFETCH_GAP
				return


func _switch() -> void:
	for p: AudioStreamPlayer in _players:
		_fading.append(p)
	_players.clear()
	_cur = track
	if _cur == "":
		return
	for s: int in range(MusicSynth.mu_stem_count(_cur)):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_level = 0.0


func _build_stem(s: int) -> void:
	var p: AudioStreamPlayer = _players[s]
	p.stream = _stream(_cur, s)
	var pos: float = 0.0
	if s > 0 and _players[0].playing:
		pos = _players[0].get_playback_position()
	p.play(pos)


func _apply() -> void:
	for s: int in range(_players.size()):
		var gain: float = _level * _layer[mini(s, _layer.size() - 1)] * master
		var db: float = SILENT_DB
		if gain > 0.001 and not Flags.is_scripted_run():
			db = BASE_DB + duck_db - DREAD_DIP_DB * pow(intensity, 1.5) + linear_to_db(gain)
		_players[s].volume_db = db
