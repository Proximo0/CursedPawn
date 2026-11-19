extends TestCase
## Every sound: right length, deterministic, no clipping; ambient loops; every event kind maps.

const LEN_RANGE: Dictionary = {  ## name -> [min secs, max secs]
	"wake": [2.0, 3.2], "run_won": [1.8, 2.2], "run_lost": [1.8, 2.2], "ambient": [8.0, 10.0], "dread": [3.0, 5.0],
	"ui_click": [0.02, 0.2], "ui_hover": [0.02, 0.2], "card_deal": [0.02, 0.3], "card_flip": [0.02, 0.3],
	"wheel_tick": [0.02, 0.2], "request_pinned": [0.02, 0.4], "collector_arrive": [1.0, 1.6],
}
const FULL_SCALE: float = 32767.0


## Builds and decoded samples are cached per (name, seed): building all 55 sounds takes ~1.2 s and decoding the
## ambient loop sample by sample ~1.7 s, and several tests read the same sounds. The determinism test builds fresh.
static var _au_built: Dictionary = {}  ## "name:seed" -> AudioStreamWAV
static var _au_decoded: Dictionary = {}  ## "name:seed" -> PackedInt32Array


static func au_built(name: String, seed: int) -> AudioStreamWAV:
	var key: String = "%s:%d" % [name, seed]
	if not _au_built.has(key):
		_au_built[key] = SfxSynth.build(name, seed)
	return _au_built[key]


static func au_samples_of(name: String, seed: int) -> PackedInt32Array:
	var key: String = "%s:%d" % [name, seed]
	if not _au_decoded.has(key):
		_au_decoded[key] = au_samples(au_built(name, seed))
	return _au_decoded[key]


static func au_samples(w: AudioStreamWAV) -> PackedInt32Array:
	var data: PackedByteArray = w.data
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(data.size() / 2)
	for i: int in range(out.size()):
		out[i] = data.decode_s16(i * 2)
	return out


func test_every_recipe_has_expected_shape() -> void:
	for name: String in SfxSynth.NAMES:
		var w: AudioStreamWAV = au_built(name, 1)
		assert_true(w != null, name)
		if w == null:
			continue
		assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS, name)
		assert_eq(w.mix_rate, SfxSynth.SR, name)
		assert_false(w.stereo, name)
		var secs: float = float(w.data.size()) / 2.0 / float(SfxSynth.SR)
		var rng: Array = LEN_RANGE.get(name, [0.02, 1.5])
		assert_true(secs >= float(rng[0]) and secs <= float(rng[1]), "%s length %f" % [name, secs])
		assert_eq(w.loop_mode == AudioStreamWAV.LOOP_FORWARD, SfxSynth.LOOPS.has(name), name + " loop flag")


func test_same_seed_same_bytes_and_noise_differs_by_seed() -> void:
	for name: String in ["footsteps", "wake", "touch", "ambient"]:
		var a: AudioStreamWAV = SfxSynth.build(name, 7)
		var b: AudioStreamWAV = SfxSynth.build(name, 7)
		assert_true(a.data == b.data, name + " same seed")
		assert_false(a.data == SfxSynth.build(name, 8).data, name + " other seed")


func test_no_clipping_and_not_silent() -> void:
	for name: String in SfxSynth.NAMES:
		var peak: int = 0
		for v: int in au_samples_of(name, 1):
			peak = maxi(peak, absi(v))
		assert_true(peak < int(0.95 * FULL_SCALE), "%s peak %d" % [name, peak])
		assert_true(peak > 500, "%s too quiet, peak %d" % [name, peak])


func test_ambient_loops_seamlessly() -> void:
	for name: String in SfxSynth.LOOPS:
		var w: AudioStreamWAV = au_built(name, 3)
		var s: PackedInt32Array = au_samples_of(name, 3)
		assert_eq(w.loop_begin, 0)
		assert_eq(w.loop_end, s.size())
		var step: int = 0  ## biggest sample-to-sample jump inside the loop, as the yardstick for the seam
		for i: int in range(1, s.size()):
			step = maxi(step, absi(s[i] - s[i - 1]))
		var seam: int = absi(s[0] - s[s.size() - 1])
		assert_true(seam <= maxi(step, 1) , "%s seam %d vs max step %d" % [name, seam, step])
		assert_true(absi(s[0]) < 3000 and absi(s[s.size() - 1]) < 3000, name + " ends near zero")


func test_levels() -> void:
	var s: PackedInt32Array = au_samples_of("ambient", 1)
	var acc: float = 0.0
	for v: int in s:
		acc += float(v) * float(v)
	var rms_db: float = 20.0 * log(sqrt(acc / float(s.size())) / FULL_SCALE) / log(10.0)
	assert_true(rms_db > -20.0 and rms_db < -16.0, "ambient rms %f dB" % rms_db)


func test_every_event_kind_maps_in_player() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var p: SfxPlayer = SfxPlayer.new()
	root.add_child(p)
	var samples: Array[Dictionary] = [
		{"e": "night_start", "night": 1, "rent": 40},
		{"e": "customer", "kind": "seller", "name": "A", "ask": 50, "type": "x", "tid": "x", "line": ""},
		{"e": "inspected", "tool": "uv", "tell": "glows", "estimate": {}},
		{"e": "inspected", "tool": "scale", "tell": "", "estimate": {}},
		{"e": "inspected", "tool": "listen", "tell": "hum", "estimate": {}},
		{"e": "inspected", "tool": "touch", "tell": "", "estimate": {}},
		{"e": "counter", "offer": 10, "ask": 40, "patience": 2},
		{"e": "left", "offer": 0},
		{"e": "bought", "uid": 1, "name": "x", "price": 20},
		{"e": "sold", "uid": 1, "name": "x", "price": 20, "imposter": false},
		{"e": "sold", "uid": 1, "name": "x", "price": 200, "imposter": true},
		{"e": "sold", "uid": 1, "name": "x", "price": 200, "imposter": false},
		{"e": "passed", "kind": "seller"},
		{"e": "wager", "card": "c", "text": "t", "stake": 5, "payout": 10, "dread": 0},
		{"e": "wager", "card": "c", "text": "t", "stake": 5, "payout": 0, "dread": 1},
		{"e": "wake", "night": 1, "dread": 9, "broke": false, "closed": false},
		{"e": "night_end", "night": 1, "rent": 40, "cash": 100, "curse_cash": 0},
		{"e": "run_lost", "night": 2, "cash": 1, "rent": 40},
		{"e": "run_won", "cash": 500},
		{"e": "invalid", "why": "no"},
		{"e": "cast", "spell": "hex", "ok": true, "backfire": false, "text": "", "dread": 0.5},
		{"e": "backfire", "spell": "hex", "kind": "x", "text": ""},
		{"e": "found", "kind": "page", "id": "hex", "name": "x"},
		{"e": "found", "kind": "curio", "id": "c", "name": "x"},
		{"e": "found_hint", "kind": "page"},
		{"e": "dice", "stake": 5, "payout": 10},
		{"e": "hand_card", "who": "you", "card": 4, "total": 4},
		{"e": "hand_end", "you": 5, "house": 7, "win": false, "stake": 5, "payout": 0},
		{"e": "wheel", "stake": 5, "payout": 0, "prize": "", "dread": 0.0},
		{"e": "pairs_deal", "count": 8, "tries": 4},
		{"e": "pairs_flip", "i": 1, "card": "a", "name": "a"},
		{"e": "pairs_match", "card": "a", "name": "a", "mult": 2.0, "dread": 0.0},
		{"e": "pairs_miss", "a": 1, "b": 2},
		{"e": "pairs_end", "matches": 1, "stake": 5, "payout": 8, "dread": 0.0},
		{"e": "item_staked", "uid": 1, "name": "x", "win": true, "value": 9},
		{"e": "lot", "name": "x", "price": 10, "item_uid": 1, "hidden": false},
		{"e": "table_open", "night": 1, "games_left": 2, "lots_left": 1},
		{"e": "request_done", "id": "r", "pay": 5, "reward": ""},
		{"e": "request_failed", "id": "r"},
		{"e": "collector_omen", "text": "t", "night": 3},
		{"e": "collector_arrives", "want_text": "t", "line": ""},
		{"e": "collector_pleased"},
		{"e": "collector_refused"},
	]
	var seen: Dictionary = {}
	for ev: Dictionary in samples:
		seen[ev["e"]] = true
		var before: int = p.played.size()
		p.on_events([ev] as Array[Dictionary])
		assert_true(p.played.size() > before, "event %s made no sound" % ev["e"])
	for kind: String in SfxPlayer.EVENT_KINDS:
		assert_true(seen.has(kind), "no sample for " + kind)
	p.on_events([{"e": "unknown_kind"}] as Array[Dictionary])  ## tolerated
	p.ui("click")
	p.ui("hover")
	for kind: String in ["omen_flip", "altar_buy", "haunt_unlock", "request_pinned", "deed", "regular"]:
		var n: int = p.played.size()
		p.ui(kind)
		assert_true(p.played.size() > n, "ui kind " + kind)
	for name: String in SfxPlayer.UI_SOUNDS.values():
		assert_true(SfxSynth.NAMES.has(name), name)
	for spell: String in ["scry", "hex", "glamour", "banish", "summon", "seal"]:
		assert_true(SfxSynth.NAMES.has("cast_" + spell), spell)
	p.set_dread(0.8)
	p.set_muted(true)
	p.set_master_volume(0.5)
	p.free()
