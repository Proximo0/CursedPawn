extends TestCase
## Music: every track builds within the budget, is deterministic, loops seamlessly, sits at its loudness, and the player
## follows events and intensity.

const FULL_SCALE: float = 32767.0

static var _built: Dictionary = {}  ## "track:stem" -> AudioStreamWAV
const SHARDED_ALLOWANCE: float = 2.0
static var _track_ms: Dictionary = {}  ## track -> ms to build all stems


static func mt_stem(track: String, stem: int) -> AudioStreamWAV:
	var key: String = "%s:%d" % [track, stem]
	if not _built.has(key):
		var t0: int = Time.get_ticks_usec()
		_built[key] = MusicSynth.build_stem(track, stem, 1)
		_track_ms[track] = float(_track_ms.get(track, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0
	return _built[key]


func test_track_build_time_within_budget() -> void:
	for track: String in MusicSynth.TRACKS:
		for s: int in range(MusicSynth.mu_stem_count(track)):
			mt_stem(track, s)
		var ms: float = float(_track_ms[track])
		# Unit tests run sharded across every CPU, so wall time here is about 1.5x a quiet machine's. This catches a
		# real regression (2x the budget); tests/perf/perf.gd checks the strict budget with the CPU to itself.
		assert_true(ms <= MusicSynth.BUDGET_SECS * 1000.0 * SHARDED_ALLOWANCE, "%s built in %.0f ms" % [track, ms])


func test_shapes_and_loops() -> void:
	assert_eq(MusicSynth.mu_stem_count("shop"), 3)
	assert_eq(MusicSynth.mu_stem_count("nope"), 0)
	assert_true(MusicSynth.build_stem("nope", 0) == null)
	for track: String in MusicSynth.TRACKS:
		for s: int in range(MusicSynth.mu_stem_count(track)):
			var w: AudioStreamWAV = mt_stem(track, s)
			var name: String = "%s/%d" % [track, s]
			assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS, name)
			assert_false(w.stereo, name)
			assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, name)
			var n: int = w.data.size() / 2
			assert_eq(w.loop_end, n, name)
			var secs: float = float(n) / float(w.mix_rate)
			assert_true(absf(secs - MusicSynth.mu_loop_secs(track)) < 0.01, "%s length %f" % [name, secs])
			var peak: int = 0
			var acc: float = 0.0
			var step: int = 0
			var prev: int = w.data.decode_s16(0)
			for i: int in range(n):
				var v: int = w.data.decode_s16(i * 2)
				peak = maxi(peak, absi(v))
				acc += float(v) * float(v)
				step = maxi(step, absi(v - prev))
				prev = v
			assert_true(peak < int(0.75 * FULL_SCALE), "%s peak %d" % [name, peak])
			var rms_db: float = 20.0 * log(sqrt(acc / float(n)) / FULL_SCALE) / log(10.0)
			assert_true(rms_db > -30.0 and rms_db < -20.0, "%s rms %f dB" % [name, rms_db])
			var seam: int = absi(w.data.decode_s16(0) - w.data.decode_s16((n - 1) * 2))
			assert_true(seam <= maxi(step, 1), "%s seam %d vs max step %d" % [name, seam, step])


func test_deterministic_and_seeded() -> void:
	var a: AudioStreamWAV = MusicSynth.build_stem("table", 1, 5)
	var b: AudioStreamWAV = MusicSynth.build_stem("table", 1, 5)
	var c: AudioStreamWAV = MusicSynth.build_stem("table", 1, 6)
	assert_true(a.data == b.data, "same seed")
	assert_true(c != null)


func test_player_follows_events_and_intensity() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var sfx: SfxPlayer = SfxPlayer.new()
	root.add_child(sfx)
	var m: MusicPlayer = sfx.music
	assert_eq(m.track, "")
	sfx.start_ambient()
	assert_eq(m.track, "title")
	sfx.on_events([{"e": "night_start", "night": 1, "rent": 40}] as Array[Dictionary])
	assert_eq(m.track, "shop")
	sfx.on_events([{"e": "table_open", "night": 1, "games_left": 2, "lots_left": 1}] as Array[Dictionary])
	assert_eq(m.track, "table")
	sfx.on_events([{"e": "collector_arrives", "want_text": "t", "line": ""}] as Array[Dictionary])
	assert_eq(m.track, "collector")
	sfx.set_dread(0.7)
	assert_true(absf(m.intensity - 0.7) < 0.001)
	sfx.on_events([{"e": "wake", "night": 1, "dread": 9, "broke": false, "closed": false}] as Array[Dictionary])
	assert_true(m._duck_target < 0.0, "a wake ducks the music")
	sfx.on_events([{"e": "run_won", "cash": 5}] as Array[Dictionary])
	assert_eq(m.track, "")
	m.play_track("not_a_track")
	assert_eq(m.track, "")
	sfx.set_music_volume(0.5)
	assert_true(absf(m.master - 0.5) < 0.001)
	assert_eq(m.build_all("collector") > 0.0, true)
	assert_true(m.is_ready("collector"))
	sfx.free()
