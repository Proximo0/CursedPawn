class_name SfxSynth
extends RefCounted
## Procedural sound: every effect is synthesised into an AudioStreamWAV (16-bit mono, 22050 Hz). Pure and static:
## no files, no clock, noise from a seeded RandomNumberGenerator, so the same seed gives identical bytes.
## Helpers are au_* (float buffers in -1..1); one recipe per sound; build(name, seed) dispatches by name.

const SR: int = 22050
const SINE: int = 0
const SQUARE: int = 1
const SAW: int = 2
const NOISE: int = 3

const STINGER_PEAK: float = 0.7  ## -3 dBFS
const SFX_PEAK: float = 0.5
const AMBIENT_RMS: float = 0.125  ## -18 dBFS
const DREAD_RMS: float = 0.1
const AMBIENT_SECS: float = 9.0
const DREAD_SECS: float = 4.0

const NAMES: PackedStringArray = [
	"door_bell", "footsteps", "coin_clink", "cash_register", "uv_lamp", "scale_clank", "listen", "touch",
	"tell_found", "haggle_counter", "customer_left", "tarot_flip", "tarot_win", "tarot_lose", "wake", "night_end",
	"run_won", "run_lost", "ui_click", "ui_hover", "wrong_note", "ambient", "dread",
]
## Sounds that loop (ambient bed and dread layer); the rest are one-shots.
const LOOPS: PackedStringArray = ["ambient", "dread"]


# ---------------------------------------------------------------- helpers

static func au_buf(secs: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(int(secs * SR))
	return b


static func au_rng(name: String, seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash([name, seed_value])
	return r


## ADSR value at time t of a voice lasting dur: linear attack a, exponential decay d to level s, linear release r.
static func au_env(t: float, dur: float, a: float, d: float, s: float, r: float) -> float:
	var v: float
	if t < a:
		v = t / maxf(a, 0.0001)
	else:
		v = s + (1.0 - s) * exp(-5.0 * (t - a) / maxf(d, 0.0001))
	var rel_start: float = dur - r
	if t > rel_start:
		v *= maxf(0.0, (dur - t) / maxf(r, 0.0001))
	return v


## Adds one voice into buf: wave at t0 for dur seconds, pitch sliding f0 -> f1, peak amp, env = (a, d, s, r).
## lp is a one-pole low-pass coefficient (1 = off, small = dark) used on NOISE only. duty is the square pulse width.
static func au_voice(buf: PackedFloat32Array, wave: int, t0: float, dur: float, f0: float, f1: float, amp: float,
		env: Vector4, rng: RandomNumberGenerator, lp: float = 1.0, duty: float = 0.5) -> void:
	var i0: int = int(t0 * SR)
	var n: int = mini(int(dur * SR), buf.size() - i0)
	var phase: float = 0.0
	var y: float = 0.0
	var inv_n: float = 1.0 / maxf(float(n), 1.0)
	var inv_sr: float = 1.0 / SR
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		var f: float = f0 + (f1 - f0) * float(i) * inv_n
		phase += f * inv_sr
		phase -= floorf(phase)
		var x: float
		if wave == SINE:
			x = sin(phase * TAU)
		elif wave == SQUARE:
			x = 1.0 if phase < duty else -1.0
		elif wave == SAW:
			x = 2.0 * phase - 1.0
		else:
			y += lp * (rng.randf() * 2.0 - 1.0 - y)
			x = y
		buf[i0 + i] += x * amp * au_env(t, dur, env.x, env.y, env.z, env.w)


## A struck-bell voice: inharmonic sine partials with shorter lives for the higher ones.
static func au_bell(buf: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, f: float, dur: float,
		amp: float) -> void:
	var ratios: PackedFloat32Array = [1.0, 2.76, 5.4]
	var amps: PackedFloat32Array = [1.0, 0.45, 0.2]
	for k: int in range(3):
		var d: float = dur / (1.0 + float(k) * 0.9)
		au_voice(buf, SINE, t0, d, f * ratios[k], f * ratios[k], amp * amps[k], Vector4(0.002, d * 0.5, 0.0, d * 0.4), rng)


## One-pole low-pass in place; k in (0, 1], smaller is darker.
static func au_lowpass(buf: PackedFloat32Array, k: float) -> void:
	var y: float = 0.0
	for i: int in range(buf.size()):
		y += k * (buf[i] - y)
		buf[i] = y


## Bit-crush in place: quantise to `bits` and hold each value `hold` samples.
static func au_crush(buf: PackedFloat32Array, bits: int, hold: int) -> void:
	var levels: float = pow(2.0, float(bits - 1))
	var held: float = 0.0
	for i: int in range(buf.size()):
		if i % hold == 0:
			held = roundf(buf[i] * levels) / levels
		buf[i] = held


static func au_tremolo(buf: PackedFloat32Array, rate: float, depth: float) -> void:
	for i: int in range(buf.size()):
		var m: float = 1.0 - depth * 0.5 * (1.0 + sin(TAU * rate * float(i) / SR))
		buf[i] *= m


static func au_reverse(buf: PackedFloat32Array) -> void:
	buf.reverse()


static func au_mix(dst: PackedFloat32Array, src: PackedFloat32Array, t0: float, gain: float) -> void:
	var i0: int = int(t0 * SR)
	for i: int in range(mini(src.size(), dst.size() - i0)):
		dst[i0 + i] += src[i] * gain


static func au_peak(buf: PackedFloat32Array) -> float:
	var p: float = 0.0
	for v: float in buf:
		p = maxf(p, absf(v))
	return p


static func au_rms(buf: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v: float in buf:
		s += v * v
	return sqrt(s / maxf(float(buf.size()), 1.0))


## Scales so the loudest sample sits at `peak`, fades the last 3 ms so one-shots end on zero.
static func au_norm(buf: PackedFloat32Array, peak: float) -> void:
	var p: float = au_peak(buf)
	if p <= 0.0:
		return
	var g: float = peak / p
	for i: int in range(buf.size()):
		buf[i] *= g
	var fade: int = mini(int(0.003 * SR), buf.size())
	for i: int in range(fade):
		buf[buf.size() - 1 - i] *= float(i) / float(fade)


static func au_to_wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i: int in range(buf.size()):
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


static func au_finish(buf: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	au_norm(buf, peak)
	return au_to_wav(buf)


## Equal-tempered note frequency; midi 69 = A4.
static func au_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Organ-ish tone: sines at 1x, 2x, 3x, 4x with a little vibrato by pitch slide.
static func au_organ(buf: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, f: float,
		amp: float, f_end: float) -> void:
	var weights: PackedFloat32Array = [1.0, 0.5, 0.33, 0.2]
	for k: int in range(4):
		var m: float = float(k + 1)
		au_voice(buf, SINE, t0, dur, f * m, f_end * m, amp * weights[k], Vector4(0.05, 0.3, 0.8, 0.25), rng)


# ---------------------------------------------------------------- dispatcher

static func build(name: String, seed_value: int = 1) -> AudioStreamWAV:
	var r: RandomNumberGenerator = au_rng(name, seed_value)
	match name:
		"door_bell": return door_bell(r)
		"footsteps": return footsteps(r)
		"coin_clink": return coin_clink(r)
		"cash_register": return cash_register(r)
		"uv_lamp": return uv_lamp(r)
		"scale_clank": return scale_clank(r)
		"listen": return listen(r)
		"touch": return touch(r)
		"tell_found": return tell_found(r)
		"haggle_counter": return haggle_counter(r)
		"customer_left": return customer_left(r)
		"tarot_flip": return tarot_flip(r)
		"tarot_win": return tarot_win(r)
		"tarot_lose": return tarot_lose(r)
		"wake": return wake(r)
		"night_end": return night_end(r)
		"run_won": return run_won(r)
		"run_lost": return run_lost(r)
		"ui_click": return ui_click(r)
		"ui_hover": return ui_hover(r)
		"wrong_note": return wrong_note(r)
		"ambient": return ambient(r)
		"dread": return dread(r)
	return null


# ---------------------------------------------------------------- recipes

static func door_bell(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.2)
	au_bell(b, r, 0.0, 1568.0, 0.9, 0.6)
	au_bell(b, r, 0.16, 2093.0, 1.0, 0.6)
	au_voice(b, NOISE, 0.0, 0.01, 0.0, 0.0, 0.3, Vector4(0.001, 0.005, 0.0, 0.004), r)
	return au_finish(b, SFX_PEAK)


static func footsteps(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.95)
	var times: PackedFloat32Array = [0.0, 0.24, 0.5, 0.72]
	for k: int in range(times.size()):
		var g: float = 0.7 + 0.3 * r.randf()
		au_voice(b, NOISE, times[k], 0.12, 0.0, 0.0, 0.8 * g, Vector4(0.004, 0.04, 0.0, 0.06), r, 0.18)
		au_voice(b, SINE, times[k], 0.08, 110.0, 55.0, 0.5 * g, Vector4(0.002, 0.03, 0.0, 0.04), r)
	return au_finish(b, SFX_PEAK)


static func coin_clink(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.5)
	au_voice(b, SINE, 0.0, 0.35, 2637.0, 2600.0, 0.6, Vector4(0.001, 0.08, 0.0, 0.1), r)
	au_voice(b, SINE, 0.0, 0.3, 3951.0, 3900.0, 0.35, Vector4(0.001, 0.05, 0.0, 0.1), r)
	au_voice(b, SINE, 0.07, 0.4, 3135.0, 3100.0, 0.5, Vector4(0.001, 0.09, 0.0, 0.12), r)
	au_voice(b, NOISE, 0.0, 0.008, 0.0, 0.0, 0.25, Vector4(0.001, 0.004, 0.0, 0.003), r)
	return au_finish(b, SFX_PEAK)


static func cash_register(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.3)
	au_voice(b, NOISE, 0.0, 0.05, 0.0, 0.0, 0.5, Vector4(0.002, 0.02, 0.0, 0.03), r, 0.5)
	au_voice(b, NOISE, 0.05, 0.22, 0.0, 0.0, 0.3, Vector4(0.02, 0.1, 0.5, 0.08), r, 0.12)  ## drawer slide
	au_bell(b, r, 0.3, 2349.0, 0.9, 0.55)
	au_bell(b, r, 0.36, 3136.0, 0.9, 0.5)
	au_voice(b, NOISE, 0.3, 0.012, 0.0, 0.0, 0.4, Vector4(0.001, 0.005, 0.0, 0.005), r)
	for k: int in range(3):  ## coins tumbling
		au_voice(b, SINE, 0.7 + 0.09 * float(k), 0.12, 3500.0 + 400.0 * float(k), 3400.0, 0.25, Vector4(0.001, 0.04, 0.0, 0.05), r)
	return au_finish(b, STINGER_PEAK)


static func uv_lamp(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.9)
	au_voice(b, NOISE, 0.0, 0.012, 0.0, 0.0, 0.7, Vector4(0.001, 0.005, 0.0, 0.006), r)
	var hum: PackedFloat32Array = au_buf(0.9)
	au_voice(hum, SAW, 0.02, 0.86, 120.0, 120.0, 0.5, Vector4(0.12, 0.3, 0.8, 0.3), r)
	au_voice(hum, SINE, 0.02, 0.86, 60.0, 60.0, 0.5, Vector4(0.1, 0.3, 0.9, 0.3), r)
	au_lowpass(hum, 0.12)
	au_mix(b, hum, 0.0, 1.6)
	au_voice(b, SINE, 0.02, 0.25, 1200.0, 2400.0, 0.12, Vector4(0.01, 0.1, 0.0, 0.1), r)
	return au_finish(b, SFX_PEAK)


static func scale_clank(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.8)
	var starts: PackedFloat32Array = [0.0, 0.26]
	var gains: PackedFloat32Array = [1.0, 0.5]
	for k: int in range(2):
		var t: float = starts[k]
		var g: float = gains[k]
		au_voice(b, SQUARE, t, 0.1, 190.0, 150.0, 0.4 * g, Vector4(0.001, 0.03, 0.0, 0.05), r)
		au_voice(b, SINE, t, 0.35, 523.0, 523.0, 0.5 * g, Vector4(0.001, 0.1, 0.0, 0.15), r)
		au_voice(b, SINE, t, 0.25, 1409.0, 1409.0, 0.3 * g, Vector4(0.001, 0.06, 0.0, 0.1), r)
		au_voice(b, NOISE, t, 0.02, 0.0, 0.0, 0.4 * g, Vector4(0.001, 0.008, 0.0, 0.01), r, 0.6)
	return au_finish(b, SFX_PEAK)


static func listen(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.25)
	var beats: PackedFloat32Array = [0.0, 0.17, 0.62, 0.79]
	var gains: PackedFloat32Array = [1.0, 0.7, 1.0, 0.7]
	for k: int in range(4):
		au_voice(b, SINE, beats[k], 0.2, 70.0, 38.0, 0.9 * gains[k], Vector4(0.01, 0.07, 0.0, 0.08), r)
		au_voice(b, NOISE, beats[k], 0.1, 0.0, 0.0, 0.5 * gains[k], Vector4(0.005, 0.03, 0.0, 0.05), r, 0.04)
	au_lowpass(b, 0.25)
	return au_finish(b, SFX_PEAK)


static func touch(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.0)
	var n: PackedFloat32Array = au_buf(1.0)
	au_voice(n, NOISE, 0.0, 0.95, 0.0, 0.0, 0.6, Vector4(0.25, 0.4, 0.6, 0.4), r, 0.7)
	au_tremolo(n, 26.0, 0.8)
	au_mix(b, n, 0.0, 1.0)
	au_voice(b, SINE, 0.0, 0.9, 900.0, 1500.0, 0.25, Vector4(0.3, 0.3, 0.5, 0.4), r)
	au_voice(b, SINE, 0.0, 0.9, 907.0, 1511.0, 0.25, Vector4(0.3, 0.3, 0.5, 0.4), r)
	return au_finish(b, SFX_PEAK)


static func tell_found(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.4)
	au_bell(b, r, 0.0, 880.0, 1.3, 0.5)
	au_bell(b, r, 0.12, 1325.0, 1.2, 0.35)
	au_bell(b, r, 0.24, 932.0, 1.1, 0.3)  ## a half step above the root: the unsettling note
	au_voice(b, SINE, 0.0, 1.3, 1760.0, 1740.0, 0.2, Vector4(0.2, 0.5, 0.3, 0.5), r)
	return au_finish(b, STINGER_PEAK)


static func haggle_counter(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.36)
	au_voice(b, SQUARE, 0.0, 0.11, 240.0, 170.0, 0.6, Vector4(0.003, 0.05, 0.3, 0.04), r, 1.0, 0.35)
	au_voice(b, SQUARE, 0.14, 0.2, 200.0, 120.0, 0.6, Vector4(0.003, 0.08, 0.3, 0.08), r, 1.0, 0.35)
	au_crush(b, 6, 2)
	return au_finish(b, SFX_PEAK)


static func customer_left(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.75)
	au_voice(b, SINE, 0.0, 0.25, 120.0, 45.0, 0.9, Vector4(0.003, 0.08, 0.0, 0.12), r)
	au_voice(b, NOISE, 0.0, 0.08, 0.0, 0.0, 0.7, Vector4(0.002, 0.03, 0.0, 0.04), r, 0.2)
	au_voice(b, NOISE, 0.2, 0.012, 0.0, 0.0, 0.4, Vector4(0.001, 0.005, 0.0, 0.005), r, 0.7)  ## latch
	au_bell(b, r, 0.05, 2093.0, 0.6, 0.12)  ## the bell above the door, jostled
	return au_finish(b, SFX_PEAK)


static func tarot_flip(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.4)
	au_voice(b, NOISE, 0.0, 0.18, 0.0, 0.0, 0.6, Vector4(0.1, 0.06, 0.3, 0.06), r, 0.4)
	au_voice(b, NOISE, 0.2, 0.03, 0.0, 0.0, 0.7, Vector4(0.001, 0.01, 0.0, 0.015), r, 0.35)
	au_voice(b, SINE, 0.2, 0.15, 500.0, 300.0, 0.2, Vector4(0.002, 0.05, 0.0, 0.08), r)
	return au_finish(b, SFX_PEAK)


static func tarot_win(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.3)
	var notes: PackedFloat32Array = [72.0, 76.0, 79.0, 84.0]
	for k: int in range(4):
		var f: float = au_hz(notes[k])
		var t: float = 0.1 * float(k)
		au_voice(b, SINE, t, 1.2 - t, f, f, 0.5, Vector4(0.005, 0.5, 0.2, 0.4), r)
		au_voice(b, SQUARE, t, 0.6, f, f, 0.12, Vector4(0.005, 0.2, 0.0, 0.2), r, 1.0, 0.25)
	au_bell(b, r, 0.3, 2093.0, 0.9, 0.3)
	return au_finish(b, STINGER_PEAK)


static func tarot_lose(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	var notes: PackedFloat32Array = [64.0, 63.0, 60.0]
	var saw: PackedFloat32Array = au_buf(1.5)
	for k: int in range(3):
		var f: float = au_hz(notes[k])
		var t: float = 0.28 * float(k)
		au_voice(saw, SAW, t, 1.4 - t, f, f * 0.98, 0.5, Vector4(0.02, 0.5, 0.5, 0.4), r)
	au_lowpass(saw, 0.18)
	au_mix(b, saw, 0.0, 1.5)
	au_voice(b, SINE, 0.0, 0.5, 80.0, 40.0, 0.8, Vector4(0.005, 0.15, 0.0, 0.2), r)
	return au_finish(b, STINGER_PEAK)


static func wake(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.8)
	var rumble: PackedFloat32Array = au_buf(2.8)
	au_voice(rumble, NOISE, 0.0, 2.6, 0.0, 0.0, 1.0, Vector4(1.1, 1.0, 0.7, 1.2), r, 0.03)
	au_voice(rumble, SINE, 0.0, 2.6, 38.0, 30.0, 0.6, Vector4(1.0, 1.0, 0.7, 1.2), r)
	au_mix(b, rumble, 0.0, 3.0)
	var whoosh: PackedFloat32Array = au_buf(1.1)  ## built as a fading burst, then reversed into a swell
	au_voice(whoosh, NOISE, 0.0, 1.1, 0.0, 0.0, 0.8, Vector4(0.005, 0.4, 0.0, 0.1), r, 0.15)
	au_reverse(whoosh)
	au_mix(b, whoosh, 0.0, 0.8)
	au_voice(b, NOISE, 1.1, 0.7, 0.0, 0.0, 1.0, Vector4(0.002, 0.2, 0.0, 0.2), r, 0.45)  ## crash
	au_voice(b, SINE, 1.1, 0.5, 90.0, 35.0, 0.9, Vector4(0.002, 0.15, 0.0, 0.2), r)
	for k: int in range(26):  ## glass: short high pings scattered over 0.6 s
		var t: float = 1.28 + r.randf() * 0.6
		var f: float = 2800.0 + r.randf() * 6000.0
		au_voice(b, SINE, t, 0.12, f, f * 0.98, 0.1 + 0.12 * r.randf(), Vector4(0.0005, 0.03, 0.0, 0.07), r)
	au_voice(b, NOISE, 1.28, 0.35, 0.0, 0.0, 0.25, Vector4(0.001, 0.1, 0.0, 0.15), r, 0.9)
	au_bell(b, r, 1.75, 262.0, 1.0, 0.6)
	return au_finish(b, STINGER_PEAK)


static func night_end(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	var notes: PackedFloat32Array = [72.0, 76.0, 74.0, 67.0]
	for k: int in range(4):
		au_bell(b, r, 0.3 * float(k), au_hz(notes[k]), 1.1 - 0.15 * float(k) * 0.5, 0.6)
	return au_finish(b, STINGER_PEAK)


static func run_won(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.0)
	var mel: PackedFloat32Array = [72.0, 75.0, 79.0, 75.0, 77.0, 80.0, 84.0]  ## C Eb G Eb F Ab C: jaunty, a bit off
	var lens: PackedFloat32Array = [0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.2]
	var t: float = 0.0
	for k: int in range(mel.size()):
		var f: float = au_hz(mel[k])
		au_voice(b, SQUARE, t, lens[k] + 0.04, f, f, 0.4, Vector4(0.003, 0.1, 0.4, 0.04), r, 1.0, 0.25)
		au_voice(b, SAW, t, lens[k], f * 0.5, f * 0.5, 0.2, Vector4(0.003, 0.1, 0.5, 0.04), r)
		t += lens[k]
	var chord: PackedFloat32Array = [72.0, 75.0, 79.0, 84.0]
	for c: float in chord:
		au_voice(b, SQUARE, t, 2.0 - t, au_hz(c), au_hz(c), 0.2, Vector4(0.005, 0.6, 0.3, 0.5), r, 1.0, 0.25)
	au_bell(b, r, t, au_hz(96.0), 0.7, 0.3)
	au_crush(b, 8, 1)
	return au_finish(b, STINGER_PEAK)


static func run_lost(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.0)
	var notes: PackedFloat32Array = [58.0, 56.0, 53.0, 50.0]  ## Bb3 Ab3 F3 D3
	for k: int in range(4):
		var f: float = au_hz(notes[k])
		var t: float = 0.4 * float(k)
		var d: float = 2.0 - t if k == 3 else 0.55
		au_organ(b, r, t, d, f, 0.5, f * (0.97 if k == 3 else 1.0))
	au_lowpass(b, 0.3)
	return au_finish(b, STINGER_PEAK)


static func ui_click(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.06)
	au_voice(b, SQUARE, 0.0, 0.05, 1300.0, 800.0, 0.5, Vector4(0.001, 0.015, 0.0, 0.02), r)
	return au_finish(b, 0.4)


static func ui_hover(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.04)
	au_voice(b, SINE, 0.0, 0.035, 900.0, 1000.0, 0.5, Vector4(0.002, 0.01, 0.0, 0.015), r)
	return au_finish(b, 0.2)


static func wrong_note(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.55)
	au_voice(b, SAW, 0.0, 0.5, 311.0, 305.0, 0.5, Vector4(0.005, 0.3, 0.5, 0.15), r)
	au_voice(b, SAW, 0.0, 0.5, 330.0, 322.0, 0.5, Vector4(0.005, 0.3, 0.5, 0.15), r)  ## a semitone clash
	au_lowpass(b, 0.3)
	au_crush(b, 7, 2)
	return au_finish(b, SFX_PEAK)


## 9 s seamless bed. Every tonal part has a whole number of cycles in the loop, the rumble is low-passed twice around
## the circle so its state wraps, and the creak fades to zero before the end.
static func ambient(r: RandomNumberGenerator) -> AudioStreamWAV:
	var n: int = int(AMBIENT_SECS * SR)
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(n)
	var rumble: PackedFloat32Array = PackedFloat32Array()
	rumble.resize(n)
	for i: int in range(n):
		rumble[i] = r.randf() * 2.0 - 1.0
	au_lowpass(rumble, 0.02)
	au_lowpass(rumble, 0.02)  ## second pass starts from the first pass's end state
	var rp: float = au_peak(rumble)
	var drone_a: float = 2.0 * PI * 55.0 / SR  ## 55 Hz * 9 s = 495 cycles
	var drone_b: float = 2.0 * PI * (743.0 / AMBIENT_SECS) / SR  ## 743 whole cycles, about 82.6 Hz
	var wob: float = 2.0 * PI * (2.0 / AMBIENT_SECS) / SR
	for i: int in range(n):
		var fi: float = float(i)
		b[i] = 0.5 * sin(drone_a * fi) + 0.3 * sin(drone_b * fi + 0.7 * sin(wob * fi)) + 0.35 * rumble[i] / rp
	var tick_gap: int = SR  ## one tick a second; 9 ticks
	var tick_len: int = int(0.02 * SR)
	for k: int in range(int(AMBIENT_SECS)):
		var start: int = k * tick_gap + int(0.5 * SR)
		var side: float = 1.0 if k % 2 == 0 else 0.8  ## tick and slightly softer tock
		for j: int in range(tick_len):
			if start + j < n:
				var e: float = exp(-6.0 * float(j) / float(tick_len))
				b[start + j] += side * 0.18 * e * sin(TAU * (1900.0 if k % 2 == 0 else 1500.0) * float(j) / SR)
	var creak: PackedFloat32Array = au_buf(0.9)
	au_voice(creak, SAW, 0.0, 0.9, 140.0, 95.0, 0.5, Vector4(0.25, 0.4, 0.4, 0.4), r, 1.0)
	au_tremolo(creak, 17.0, 0.7)
	au_lowpass(creak, 0.2)
	au_mix(b, creak, 5.6, 0.9)
	var rms: float = au_rms(b)
	var g: float = AMBIENT_RMS / rms
	var pk: float = au_peak(b) * g
	if pk > 0.9:
		g *= 0.9 / pk
	for i: int in range(n):
		b[i] *= g
	return au_to_wav(b, true)


## 4 s seamless detuned shimmer: pairs of sines a hair apart (beats at 0.5-1.5 Hz), slow swell. Whole cycles in 4 s.
static func dread(_r: RandomNumberGenerator) -> AudioStreamWAV:
	var n: int = int(DREAD_SECS * SR)
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(n)
	var freqs: PackedFloat32Array = [440.0, 440.75, 659.25, 660.5, 880.0, 881.5, 1318.5, 1320.25]
	var amps: PackedFloat32Array = [0.5, 0.5, 0.35, 0.35, 0.25, 0.25, 0.15, 0.15]
	for k: int in range(freqs.size()):
		var w: float = TAU * freqs[k] / SR
		var a: float = amps[k]
		for i: int in range(n):
			b[i] += a * sin(w * float(i))
	for i: int in range(n):
		b[i] *= 0.7 + 0.3 * sin(TAU * 0.5 * float(i) / SR)  ## 2 swells in the loop
	var g: float = DREAD_RMS / au_rms(b)
	for i: int in range(n):
		b[i] *= g
	return au_to_wav(b, true)
