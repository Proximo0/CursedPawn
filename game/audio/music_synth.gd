class_name MusicSynth
extends RefCounted
## Procedural, original music for the shop: low strings from filtered saws, bowed glass, a warped music-box motif and slow
## organ, over a drone that matches the ambient bed (A, 55 Hz). Pure and static: no files, no clock, noise from a seeded
## generator, so the same seed gives identical bytes. A track is a loop split into stems (layers) that the player fades with
## Dread; every stem is its own mono AudioStreamWAV with whole-loop length, so stems stay in sync and loop seamlessly.
## Notes are rendered into small buffers (cached per build) and mixed in with wrap-around, so tails cross the loop seam.

const TRACKS: PackedStringArray = ["title", "shop", "table", "collector"]
const STEM_RMS: PackedFloat32Array = [0.07, 0.055, 0.05]  ## per stem index, about -23 to -26 dBFS
const STEM_PEAK: float = 0.7
const BUDGET_SECS: float = 2.5  ## the whole of one track, every stem, must build within this

## Per track: {bpm, beats, sr (per stem)}. Loop length = beats * 60 / bpm.
const CONF: Dictionary = {
	"title": {"bpm": 56.0, "beats": 16, "sr": [11025, 5512]},
	"shop": {"bpm": 72.0, "beats": 24, "sr": [11025, 5512, 11025]},
	"table": {"bpm": 96.0, "beats": 16, "sr": [11025, 5512]},
	"collector": {"bpm": 48.0, "beats": 16, "sr": [5512, 11025]},
}


static func mu_stem_count(track: String) -> int:
	return (CONF[track]["sr"] as Array).size() if CONF.has(track) else 0


static func mu_loop_secs(track: String) -> float:
	if not CONF.has(track):
		return 0.0
	return float(CONF[track]["beats"]) * 60.0 / float(CONF[track]["bpm"])


static func mu_beat(track: String) -> float:
	return 60.0 / float(CONF[track]["bpm"])


## One stem of a track as a looping AudioStreamWAV; null for an unknown track or stem.
static func build_stem(track: String, stem: int, seed_value: int = 1) -> AudioStreamWAV:
	if not CONF.has(track) or stem < 0 or stem >= mu_stem_count(track):
		return null
	var sr: int = int((CONF[track]["sr"] as Array)[stem])
	var secs: float = mu_loop_secs(track)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(int(secs * float(sr)))
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash(["music", track, stem, seed_value])
	var cache: Dictionary = {}
	match track:
		"title": _title(buf, sr, stem, r, cache)
		"shop": _shop(buf, sr, stem, r, cache)
		"table": _table(buf, sr, stem, r, cache)
		"collector": _collector(buf, sr, stem, r, cache)
	return mu_finish(buf, sr, STEM_RMS[mini(stem, STEM_RMS.size() - 1)])


# ---------------------------------------------------------------- mixing helpers

static func mu_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Adds src into dst starting at second t, wrapping past the end so a tail crosses the loop seam.
static func mu_place(dst: PackedFloat32Array, sr: int, src: PackedFloat32Array, t: float, gain: float) -> void:
	var n: int = dst.size()
	var j: int = int(t * float(sr)) % n
	for i: int in range(src.size()):
		dst[j] += src[i] * gain
		j += 1
		if j >= n:
			j = 0


## Scales to the stem's loudness, keeps the peak under STEM_PEAK, and wraps as a looping 16-bit mono stream.
static func mu_finish(buf: PackedFloat32Array, sr: int, rms_target: float) -> AudioStreamWAV:
	var rms: float = SfxSynth.au_rms(buf)
	var g: float = rms_target / maxf(rms, 0.00001)
	var pk: float = SfxSynth.au_peak(buf) * g
	if pk > STEM_PEAK:
		g *= STEM_PEAK / pk
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i: int in range(buf.size()):
		bytes.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w


## Cached note: key -> buffer, so a repeated motif note is rendered once per build.
static func _cached(cache: Dictionary, key: String) -> Variant:
	return cache.get(key, null)


# ---------------------------------------------------------------- voices

## Bowed low string: two detuned saws through two one-pole low-passes whose cutoff opens with the bow, slow vibrato,
## optional slide from midi0 to midi1. Dark and dry: the cutoff never passes about 1 kHz.
static func mu_string(midi0: float, midi1: float, dur: float, sr: int, attack: float, release: float) -> PackedFloat32Array:
	var n: int = int(dur * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var f0: float = mu_hz(midi0)
	var f1: float = mu_hz(midi1)
	var p1: float = 0.0
	var p2: float = 0.3
	var y1: float = 0.0
	var y2: float = 0.0
	var inv_sr: float = 1.0 / float(sr)
	var inv_a: float = 1.0 / maxf(attack, 0.001)
	var inv_r: float = 1.0 / maxf(release, 0.001)
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		var f: float = f0 + (f1 - f0) * float(i) / float(maxi(n, 1))
		f *= 1.0 + 0.003 * sin(TAU * 4.6 * t) * minf(t * 0.5, 1.0)
		p1 += f * 1.0035 * inv_sr
		p1 -= floorf(p1)
		p2 += f * 0.9965 * inv_sr
		p2 -= floorf(p2)
		var env: float = minf(t * inv_a, 1.0) * minf((dur - t) * inv_r, 1.0)
		var k: float = clampf(TAU * (200.0 + 800.0 * env) * inv_sr, 0.0, 0.9)
		var x: float = (p1 + p2) - 1.0
		y1 += k * (x - y1)
		y2 += k * (y1 - y2)
		out[i] = y2 * env * 1.6
	return out


## Bowed glass: near-pure tone with a detuned twin (slow beat) and a faint octave, swelling in and out, wobbling.
static func mu_glass(midi: float, dur: float, sr: int, attack: float, release: float) -> PackedFloat32Array:
	var n: int = int(dur * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var f: float = mu_hz(midi)
	var w1: float = TAU * f / float(sr)
	var w2: float = TAU * (f + 1.3) / float(sr)
	var w3: float = TAU * (f * 2.003) / float(sr)
	var inv_sr: float = 1.0 / float(sr)
	var inv_a: float = 1.0 / maxf(attack, 0.001)
	var inv_r: float = 1.0 / maxf(release, 0.001)
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		var env: float = minf(t * inv_a, 1.0) * minf((dur - t) * inv_r, 1.0)
		var wob: float = 1.0 + 0.18 * sin(TAU * 0.55 * t + f)
		var fi: float = float(i)
		out[i] = (sin(w1 * fi) + sin(w2 * fi) * 0.8 + sin(w3 * fi) * 0.12) * env * wob * 0.5
	return out


## Music-box tine: three inharmonic partials with short lives and a slight downward warp, like a tired comb.
static func mu_box(midi: float, dur: float, sr: int) -> PackedFloat32Array:
	var n: int = int(dur * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var f: float = mu_hz(midi)
	var inv_sr: float = 1.0 / float(sr)
	var ph: float = 0.0
	var ratios: PackedFloat32Array = [1.0, 3.98, 8.2]
	var amps: PackedFloat32Array = [1.0, 0.28, 0.1]
	var lives: PackedFloat32Array = [dur * 0.45, dur * 0.18, dur * 0.07]
	var phases: PackedFloat32Array = [0.0, 0.0, 0.0]
	var decs: PackedFloat32Array = [1.0, 1.0, 1.0]
	var ks: PackedFloat32Array = [0.0, 0.0, 0.0]
	for k: int in range(3):
		ks[k] = exp(-1.0 * inv_sr / lives[k])
	ph = 0.0
	for i: int in range(n):
		var warp: float = 1.0 - 0.012 * float(i) / float(maxi(n, 1))
		var s: float = 0.0
		for k: int in range(3):
			if ratios[k] * f * warp < float(sr) * 0.45:
				phases[k] += ratios[k] * f * warp * inv_sr
				phases[k] -= floorf(phases[k])
				s += sin(TAU * phases[k]) * amps[k] * decs[k]
			decs[k] *= ks[k]
		var fade: float = minf((n - i) * inv_sr * 80.0, 1.0)
		out[i] = s * fade * minf(float(i) * inv_sr * 1000.0, 1.0)
	return out


## Slow organ: sines at 1, 2, 3, 4 times the pitch, long attack and release, low-weighted upper partials.
static func mu_organ(midi: float, dur: float, sr: int, attack: float, release: float) -> PackedFloat32Array:
	var n: int = int(dur * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var f: float = mu_hz(midi)
	var w: float = TAU * f / float(sr)
	var inv_sr: float = 1.0 / float(sr)
	var inv_a: float = 1.0 / maxf(attack, 0.001)
	var inv_r: float = 1.0 / maxf(release, 0.001)
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		var env: float = minf(t * inv_a, 1.0) * minf((dur - t) * inv_r, 1.0)
		var a: float = w * float(i)
		out[i] = (sin(a) + 0.55 * sin(2.0 * a) + 0.3 * sin(3.0 * a)) * env * 0.42
	return out


## A dry pluck: one saw through a low-pass that closes fast. For the table's bass.
static func mu_pluck(midi: float, dur: float, sr: int) -> PackedFloat32Array:
	var n: int = int(dur * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var f: float = mu_hz(midi)
	var inv_sr: float = 1.0 / float(sr)
	var ph: float = 0.0
	var y: float = 0.0
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		ph += f * inv_sr
		ph -= floorf(ph)
		var e: float = exp(-5.0 * t / dur)
		y += clampf(TAU * (150.0 + 900.0 * e) * inv_sr, 0.0, 0.9) * ((2.0 * ph - 1.0) - y)
		out[i] = y * e * 1.4 * minf(t * 400.0, 1.0)
	return out


## A heartbeat: a lub and a softer dub, each a falling sine with a short decay.
static func mu_heart(sr: int) -> PackedFloat32Array:
	var n: int = int(0.5 * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var inv_sr: float = 1.0 / float(sr)
	for beat: int in range(2):
		var t0: int = int(float(beat) * 0.26 * float(sr))
		var amp: float = 1.0 if beat == 0 else 0.6
		var ph: float = 0.0
		for i: int in range(int(0.22 * float(sr))):
			var t: float = float(i) * inv_sr
			ph += (62.0 - 30.0 * t / 0.22) * inv_sr
			if t0 + i < n:
				out[t0 + i] += sin(TAU * ph) * exp(-14.0 * t) * amp
	return out


## A card-shuffle tick: a few milliseconds of high-passed noise.
static func mu_tick(sr: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(0.04 * float(sr))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var prev: float = 0.0
	for i: int in range(n):
		var x: float = r.randf() * 2.0 - 1.0
		out[i] = (x - prev) * exp(-7.0 * float(i) / float(n)) * 0.5
		prev = x
	return out


## A steady partial with a whole number of cycles in the loop, so it needs no envelope to loop cleanly.
static func mu_steady(dst: PackedFloat32Array, sr: int, hz: float, amp: float, swell_cycles: int, swell: float) -> void:
	var secs: float = float(dst.size()) / float(sr)
	var cycles: float = roundf(hz * secs)
	var w: float = TAU * cycles / float(dst.size())
	var sw: float = TAU * float(swell_cycles) / float(dst.size())
	for i: int in range(dst.size()):
		var fi: float = float(i)
		dst[i] += amp * sin(w * fi) * (1.0 - swell + swell * (0.5 + 0.5 * sin(sw * fi)))


## Looping wind: noise low-passed twice around the circle (the second pass starts from the first one's end state).
static func mu_wind(dst: PackedFloat32Array, sr: int, r: RandomNumberGenerator, amp: float, k: float) -> void:
	var n: int = dst.size()
	var w: PackedFloat32Array = PackedFloat32Array()
	w.resize(n)
	for i: int in range(n):
		w[i] = r.randf() * 2.0 - 1.0
	SfxSynth.au_lowpass(w, k)
	SfxSynth.au_lowpass(w, k)
	var pk: float = maxf(SfxSynth.au_peak(w), 0.0001)
	var sw: float = TAU * 2.0 / float(n)
	for i: int in range(n):
		dst[i] += amp * w[i] / pk * (0.6 + 0.4 * sin(sw * float(i)))


# ---------------------------------------------------------------- note helpers

static func _box_note(dst: PackedFloat32Array, sr: int, cache: Dictionary, midi: float, t: float, gain: float) -> void:
	var key: String = "box%d" % int(midi)
	var b: Variant = _cached(cache, key)
	if b == null:
		b = mu_box(midi, 2.2, sr)
		cache[key] = b
	mu_place(dst, sr, b as PackedFloat32Array, t, gain)


static func _motif(dst: PackedFloat32Array, sr: int, cache: Dictionary, notes: Array, t0: float, beat: float,
		gain: float, transpose: float) -> void:
	for nt: Array in notes:
		_box_note(dst, sr, cache, float(nt[1]) + transpose, t0 + float(nt[0]) * beat, gain)


## Chord pad: organ voices for each tone, `beats_each` long plus an overlap into the next chord.
static func _organ_chords(dst: PackedFloat32Array, sr: int, chords: Array, each_beats: float, beat: float,
		gain: float) -> void:
	for c: int in range(chords.size()):
		var t: float = float(c) * each_beats * beat
		var dur: float = each_beats * beat + 1.4
		for m: int in (chords[c] as Array):
			mu_place(dst, sr, mu_organ(float(m), dur, sr, 1.2, 1.6), t, gain)


static func _string_chords(dst: PackedFloat32Array, sr: int, chords: Array, each_beats: float, beat: float,
		gain: float) -> void:
	for c: int in range(chords.size()):
		var t: float = float(c) * each_beats * beat
		var dur: float = each_beats * beat + 1.6
		for m: int in (chords[c] as Array):
			mu_place(dst, sr, mu_string(float(m), float(m), dur, sr, 1.0, 1.6), t, gain)


# ---------------------------------------------------------------- tracks

## Shop: A Phrygian-ish, Am - Bb - Dm - E(major, so G# bites against the loop's G natural). Polymeter: chords change
## every 6 beats, the box motif repeats every 8, the heartbeat every 3.
static func _shop(b: PackedFloat32Array, sr: int, stem: int, r: RandomNumberGenerator, cache: Dictionary) -> void:
	var beat: float = mu_beat("shop")
	var motif: Array = [[0.0, 69], [1.0, 72], [2.0, 71], [3.0, 69], [4.5, 76], [5.5, 75], [6.5, 72]]
	if stem == 0:
		mu_steady(b, sr, 55.0, 0.5, 2, 0.25)
		mu_steady(b, sr, 110.0, 0.22, 3, 0.4)
		mu_steady(b, sr, 82.4, 0.16, 5, 0.5)
		_organ_chords(b, sr, [[45, 48, 52], [46, 50, 53], [50, 53, 57], [44, 47, 52]], 6.0, beat, 0.22)
		_motif(b, sr, cache, motif, 0.0, beat, 0.14, 0.0)  ## once per loop, quiet: the shop's own little tune
		mu_wind(b, sr, r, 0.12, 0.03)
	elif stem == 1:
		_string_chords(b, sr, [[33, 45, 48], [34, 46, 50], [38, 50, 53], [40, 52, 56]], 6.0, beat, 0.16)
		var glass: Array = [76, 74, 77, 80]
		for c: int in range(4):
			mu_place(b, sr, mu_glass(float(glass[c]), 6.2, sr, 1.5, 2.0), (float(c) * 6.0 + 0.5) * beat, 0.16)
	else:
		for rep: int in range(3):
			_motif(b, sr, cache, motif, float(rep) * 8.0 * beat, beat, 0.22, 0.0)
			_motif(b, sr, cache, motif, (float(rep) * 8.0 + 0.5) * beat, beat, 0.07, 12.0 if rep == 1 else 0.0)
		var heart: PackedFloat32Array = mu_heart(sr)
		for k: int in range(8):
			mu_place(b, sr, heart, float(k) * 3.0 * beat, 0.5)
		mu_place(b, sr, mu_glass(75.0, 9.0, sr, 3.0, 3.0), 7.0 * beat, 0.12)  ## Eb: the tritone above A


## Title: slower, the box tune out front over organ, then strings and glass.
static func _title(b: PackedFloat32Array, sr: int, stem: int, _r: RandomNumberGenerator, cache: Dictionary) -> void:
	var beat: float = mu_beat("title")
	if stem == 0:
		mu_steady(b, sr, 55.0, 0.45, 1, 0.2)
		mu_steady(b, sr, 110.0, 0.2, 2, 0.4)
		_organ_chords(b, sr, [[45, 48, 52], [41, 45, 48], [38, 50, 53], [44, 47, 52]], 4.0, beat, 0.22)
		var tune: Array = [[0.0, 76], [1.0, 72], [2.0, 69], [3.5, 71], [4.0, 72], [5.0, 76], [6.0, 75], [7.0, 71],
			[8.0, 69], [9.0, 72], [10.0, 76], [11.5, 77], [12.0, 76], [13.0, 72], [14.0, 71], [15.0, 69]]
		_motif(b, sr, cache, tune, 0.0, beat, 0.3, 0.0)
	else:
		_string_chords(b, sr, [[33, 45, 48], [29, 41, 45], [38, 50, 53], [40, 52, 56]], 4.0, beat, 0.2)
		var glass: Array = [72, 69, 74, 71]
		for c: int in range(4):
			mu_place(b, sr, mu_glass(float(glass[c]), 4.6, sr, 1.2, 1.6), float(c) * 4.0 * beat, 0.16)


## Table: D minor, a dry plucked bass and a 3+3+2 box ostinato with card ticks. Sly, not scary.
static func _table(b: PackedFloat32Array, sr: int, stem: int, r: RandomNumberGenerator, cache: Dictionary) -> void:
	var beat: float = mu_beat("table")
	var eighth: float = beat * 0.5
	if stem == 0:
		var roots: Array = [38, 38, 34, 34, 43, 43, 45, 45]  ## D D Bb Bb G G A A, two beats each (D2 = 38)
		var starts: Array = [0.0, 1.5, 3.0]
		for bar: int in range(roots.size()):
			var pluck: PackedFloat32Array = mu_pluck(float(roots[bar]), 0.9, sr)
			for s: float in starts:
				if s < 2.0:
					mu_place(b, sr, pluck, (float(bar) * 2.0 + s) * beat, 0.5 if s == 0.0 else 0.3)
		var osti: Array = [74, 77, 74, 72, 74, 72, 70, 69]  ## 3+3+2 accents by the notes' gains below
		for k: int in range(32):
			var note: float = float(osti[k % 8])
			var accent: float = 1.0 if (k % 8 == 0 or k % 8 == 3 or k % 8 == 6) else 0.55
			_box_note(b, sr, cache, note, float(k) * eighth, 0.16 * accent)
		var tick: PackedFloat32Array = mu_tick(sr, r)
		for k: int in range(16):
			mu_place(b, sr, tick, (float(k) + 0.5) * beat, 0.35)
	else:
		_organ_chords(b, sr, [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]], 4.0, beat, 0.2)
		var glass: Array = [77, 74, 70, 73]
		for c: int in range(4):
			mu_place(b, sr, mu_glass(float(glass[c]), 3.6, sr, 0.7, 1.4), float(c) * 4.0 * beat, 0.16)


## Collector: Bb and the F# a tritone above it against the shop's A drone. Glass clusters, a slowly sliding string,
## a lone inverted box phrase and a slow heartbeat. Nothing resolves.
static func _collector(b: PackedFloat32Array, sr: int, stem: int, _r: RandomNumberGenerator, cache: Dictionary) -> void:
	var beat: float = mu_beat("collector")
	if stem == 0:
		mu_steady(b, sr, 58.3, 0.5, 1, 0.3)
		mu_steady(b, sr, 92.5, 0.3, 2, 0.4)
		mu_steady(b, sr, 116.5, 0.2, 3, 0.4)
		mu_steady(b, sr, 466.2, 0.07, 2, 0.6)  ## Bb4
		mu_steady(b, sr, 493.9, 0.07, 3, 0.6)  ## B4: a minor second of beating glass
		mu_steady(b, sr, 740.0, 0.05, 1, 0.7)  ## F#5
	else:
		mu_place(b, sr, mu_string(46.0, 45.0, 11.0, sr, 3.0, 3.0), 0.0, 0.18)
		mu_place(b, sr, mu_string(52.0, 53.0, 11.0, sr, 3.0, 3.0), 10.0 * beat, 0.14)
		var inv: Array = [[0.0, 72], [1.5, 69], [3.0, 70], [5.0, 66], [6.5, 67]]  ## the shop tune turned over
		_motif(b, sr, cache, inv, 8.0 * beat, beat, 0.2, 0.0)
		var heart: PackedFloat32Array = mu_heart(sr)
		for k: int in range(8):
			mu_place(b, sr, heart, float(k) * 2.0 * beat, 0.45)
