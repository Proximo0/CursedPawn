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

## Loudness targets (active-signal RMS in dBFS, see au_active_db): every non-loop sound is normalised to its class target.
const TARGET_STINGER_DB: float = -17.0
const TARGET_SFX_DB: float = -21.0
const TARGET_UI_DB: float = -25.0  ## sounds shorter than UI_MAX_SECS
const UI_MAX_SECS: float = 0.25
const LIMIT_KNEE: float = 0.5  ## above this the soft limiter bends towards LIMIT_TOP
const LIMIT_TOP: float = 0.9
const STINGERS: PackedStringArray = ["cash_register", "tell_found", "tarot_win", "tarot_lose", "wake", "night_end", "run_won",
	"run_lost", "table_open", "collector_arrive", "collector_pleased", "collector_refused", "haunt_unlock", "event_blackout",
	"event_storm", "event_fullmoon", "wake_drift", "wake_topple", "wake_lights_out", "wake_door_lock", "wake_possession",
	"ending_debt_free", "ending_cursed_shop", "ending_collector", "ending_regulars"]
static var _cur_name: String = ""  ## the sound build() is making, so au_finish knows its loudness class

const NAMES: PackedStringArray = [
	"door_bell", "footsteps", "coin_clink", "cash_register", "uv_lamp", "scale_clank", "listen", "touch",
	"tell_found", "haggle_counter", "customer_left", "tarot_flip", "tarot_win", "tarot_lose", "wake", "night_end",
	"run_won", "run_lost", "ui_click", "ui_hover", "wrong_note", "ambient", "dread",
	"cast_scry", "cast_hex", "cast_glamour", "cast_banish", "cast_summon", "cast_seal",
	"backfire", "found_page", "found_curio", "found_hint", "dice_roll", "card_deal", "card_flip", "wheel_tick", "wheel_settle", "pairs_match",
	"pairs_miss", "stake_win", "stake_lose", "lot_unwrap", "table_open", "request_pinned", "request_done", "request_failed", "omen_flip", "collector_arrive", "collector_pleased", "collector_refused", "altar_buy", "haunt_unlock", "deed", "regular",
	"curse_shift", "curse_copied", "whispered_away", "event_blackout", "event_storm", "event_auction", "event_fullmoon", "wake_drift", "wake_topple", "wake_lights_out", "wake_door_lock", "wake_possession", "mood_nervous", "mood_greedy", "buyer_offer", "ending_debt_free", "ending_cursed_shop", "ending_collector", "ending_regulars",
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
	var df: float = f1 - f0
	var ea: float = maxf(env.x, 0.0001)
	var es: float = env.z
	var dec: float = 1.0  ## exp(-5 (t - a) / d), advanced by one multiply per sample once past the attack
	var dec_k: float = exp(-5.0 * inv_sr / maxf(env.y, 0.0001))
	var rel_start: float = dur - env.w
	var inv_r: float = 1.0 / maxf(env.w, 0.0001)
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		phase += (f0 + df * float(i) * inv_n) * inv_sr
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
		var e: float
		if t < ea:
			e = t / ea
		else:
			e = es + (1.0 - es) * dec
			dec *= dec_k
		if t > rel_start:
			e *= maxf(0.0, (dur - t) * inv_r)
		buf[i0 + i] += x * amp * e


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
	if _cur_name != "":
		au_loudness(buf, au_target_db(_cur_name, float(buf.size()) / float(SR)))
	return au_to_wav(buf)


## The loudness class target in dBFS for a one-shot of the given length.
static func au_target_db(name: String, secs: float) -> float:
	if STINGERS.has(name):
		return TARGET_STINGER_DB
	return TARGET_UI_DB if secs < UI_MAX_SECS else TARGET_SFX_DB


## Level of the sound while it is sounding, in dBFS: the mean power of the 10 ms blocks that are within about -34 dB of the
## loudest block's peak (so silence and long tails do not dilute a short ping). A simple stand-in for LUFS on short sounds.
static func au_active_db(buf: PackedFloat32Array) -> float:
	var block: int = maxi(int(0.01 * SR), 1)
	var stride: int = 3  ## every third sample is plenty for a level estimate and a third of the cost
	var pk: float = au_peak(buf)
	if pk <= 0.0:
		return -120.0
	var thr: float = pk * pk * 0.0004  ## (0.02 * peak)^2 as power
	var acc: float = 0.0
	var cnt: int = 0
	var i: int = 0
	while i < buf.size():
		var e: int = mini(i + block, buf.size())
		var p: float = 0.0
		var k: int = 0
		for j: int in range(i, e, stride):
			p += buf[j] * buf[j]
			k += 1
		p /= float(maxi(k, 1))
		if p >= thr:
			acc += p
			cnt += 1
		i = e
	return 10.0 * log(maxf(acc / float(maxi(cnt, 1)), 1e-12)) / log(10.0)


static func _limit(x: float) -> float:
	var a: float = absf(x)
	if a <= LIMIT_KNEE:
		return x
	var span: float = LIMIT_TOP - LIMIT_KNEE
	var y: float = LIMIT_KNEE + span * tanh((a - LIMIT_KNEE) / span)
	return y if x >= 0.0 else -y


## Brings the buffer's active level to target_db in place. The soft limiter keeps peaks under LIMIT_TOP; since it lowers
## the level of spiky sounds, the gain is trimmed twice against the limited result.
static func au_loudness(buf: PackedFloat32Array, target_db: float) -> void:
	var g: float = pow(10.0, (target_db - au_active_db(buf)) / 20.0)
	if au_peak(buf) * g <= LIMIT_KNEE:  ## nothing reaches the limiter, so one gain is exact
		for i: int in range(buf.size()):
			buf[i] *= g
		_fade_tail(buf)
		return
	var src: PackedFloat32Array = buf.duplicate()
	for _pass: int in range(2):
		for i: int in range(src.size()):
			buf[i] = _limit(src[i] * g)
		g *= pow(10.0, (target_db - au_active_db(buf)) / 20.0)
	for i: int in range(src.size()):
		buf[i] = _limit(src[i] * g)
	_fade_tail(buf)


static func _fade_tail(buf: PackedFloat32Array) -> void:
	var fade: int = mini(int(0.003 * SR), buf.size())
	for i: int in range(fade):
		buf[buf.size() - 1 - i] *= float(i) / float(fade)


## Equal-tempered note frequency; midi 69 = A4.
static func au_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Organ-ish tone: sines at 1x, 2x, 3x, 4x with a little vibrato by pitch slide. One pass over the buffer with one
## envelope (attack 0.05, decay 0.3 to sustain 0.8, release 0.25), the same shape the four separate voices had.
static func au_organ(buf: PackedFloat32Array, _rng: RandomNumberGenerator, t0: float, dur: float, f: float,
		amp: float, f_end: float) -> void:
	var i0: int = int(t0 * SR)
	var n: int = mini(int(dur * SR), buf.size() - i0)
	var inv_sr: float = 1.0 / SR
	var inv_n: float = 1.0 / maxf(float(n), 1.0)
	var dec: float = 1.0
	var dec_k: float = exp(-5.0 * inv_sr / 0.3)
	var rel_start: float = dur - 0.25
	var phase: float = 0.0  ## fundamental phase in cycles; the partials are multiples of it
	for i: int in range(n):
		var t: float = float(i) * inv_sr
		phase += (f + (f_end - f) * float(i) * inv_n) * inv_sr
		var e: float
		if t < 0.05:
			e = t / 0.05
		else:
			e = 0.8 + 0.2 * dec
			dec *= dec_k
		if t > rel_start:
			e *= maxf(0.0, (dur - t) * 4.0)
		var a: float = TAU * (phase - floorf(phase))
		buf[i0 + i] += (sin(a) + 0.5 * sin(2.0 * a) + 0.33 * sin(3.0 * a) + 0.2 * sin(4.0 * a)) * amp * e


# ---------------------------------------------------------------- dispatcher

static func build(name: String, seed_value: int = 1) -> AudioStreamWAV:
	_cur_name = name if not LOOPS.has(name) else ""
	var w: AudioStreamWAV = _dispatch(name, au_rng(name, seed_value))
	_cur_name = ""
	return w


static func _dispatch(name: String, r: RandomNumberGenerator) -> AudioStreamWAV:
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
		"cast_scry": return cast_scry(r)
		"cast_hex": return cast_hex(r)
		"cast_glamour": return cast_glamour(r)
		"cast_banish": return cast_banish(r)
		"cast_summon": return cast_summon(r)
		"cast_seal": return cast_seal(r)
		"backfire": return backfire(r)
		"found_page": return found_page(r)
		"found_curio": return found_curio(r)
		"found_hint": return found_hint(r)
		"dice_roll": return dice_roll(r)
		"card_deal": return card_deal(r)
		"card_flip": return card_flip(r)
		"wheel_tick": return wheel_tick(r)
		"wheel_settle": return wheel_settle(r)
		"pairs_match": return pairs_match(r)
		"pairs_miss": return pairs_miss(r)
		"stake_win": return stake_win(r)
		"stake_lose": return stake_lose(r)
		"lot_unwrap": return lot_unwrap(r)
		"table_open": return table_open(r)
		"request_pinned": return request_pinned(r)
		"request_done": return request_done(r)
		"request_failed": return request_failed(r)
		"omen_flip": return omen_flip(r)
		"collector_arrive": return collector_arrive(r)
		"collector_pleased": return collector_pleased(r)
		"collector_refused": return collector_refused(r)
		"altar_buy": return altar_buy(r)
		"haunt_unlock": return haunt_unlock(r)
		"deed": return deed(r)
		"regular": return regular(r)
		"curse_shift": return curse_shift(r)
		"curse_copied": return curse_copied(r)
		"whispered_away": return whispered_away(r)
		"event_blackout": return event_blackout(r)
		"event_storm": return event_storm(r)
		"event_auction": return event_auction(r)
		"event_fullmoon": return event_fullmoon(r)
		"wake_drift": return wake_drift(r)
		"wake_topple": return wake_topple(r)
		"wake_lights_out": return wake_lights_out(r)
		"wake_door_lock": return wake_door_lock(r)
		"wake_possession": return wake_possession(r)
		"mood_nervous": return mood_nervous(r)
		"mood_greedy": return mood_greedy(r)
		"buyer_offer": return buyer_offer(r)
		"ending_debt_free": return ending_debt_free(r)
		"ending_cursed_shop": return ending_cursed_shop(r)
		"ending_collector": return ending_collector(r)
		"ending_regulars": return ending_regulars(r)
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
	## One low breath per loop with near-silence between, not a held chord: A3 and E4 with slow-beating twins.
	var n: int = int(DREAD_SECS * SR)
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(n)
	var freqs: PackedFloat32Array = [220.0, 220.5, 329.5, 330.0, 440.0]  ## whole cycles in the 4 s loop, so the seam is clean
	var amps: PackedFloat32Array = [0.5, 0.5, 0.25, 0.25, 0.08]
	for k: int in range(freqs.size()):
		var w: float = TAU * freqs[k] / SR
		var a: float = amps[k]
		for i: int in range(n):
			b[i] += a * sin(w * float(i))
	for i: int in range(n):
		var x: float = float(i) / float(n)  ## the breath: peaks at 0.42 of the loop, gone by 0.85, then a low floor
		var breath: float = sin(PI * clampf(x / 0.85, 0.0, 1.0))
		b[i] *= 0.06 + 0.94 * breath * breath
	var g: float = DREAD_RMS / au_rms(b)
	for i: int in range(n):
		b[i] *= g
	return au_to_wav(b, true)


# ---------------------------------------------------------------- round 5: spells, finds, the table, the Collector

## The shared spell voice: a low-passed breath swelling in, a glided organ tone and a wax-soft thud. The six casts
## differ in pitch, direction and one colour (bell, shimmer, rattle).
static func _cast(r: RandomNumberGenerator, f0: float, f1: float, colour: int) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.7)
	var breath: PackedFloat32Array = au_buf(0.5)
	au_voice(breath, NOISE, 0.0, 0.5, 0.0, 0.0, 1.0, Vector4(0.2, 0.15, 0.4, 0.2), r, 0.12)
	au_mix(b, breath, 0.0, 0.8)
	au_organ(b, r, 0.02, 0.6, f0, 0.3, f1)
	au_voice(b, SINE, 0.0, 0.12, 110.0, 60.0, 0.5, Vector4(0.003, 0.04, 0.0, 0.06), r)
	if colour == 0:  ## scry: a glass bell far off
		au_bell(b, r, 0.2, f1 * 3.0, 0.45, 0.18)
	elif colour == 1:  ## hex: a dry rattle of knuckle bones
		for k: int in range(4):
			au_voice(b, NOISE, 0.1 + 0.07 * float(k), 0.02, 0.0, 0.0, 0.4, Vector4(0.001, 0.008, 0.0, 0.01), r, 0.3)
	elif colour == 2:  ## glamour: a slow shimmer
		var sh: PackedFloat32Array = au_buf(0.7)
		au_voice(sh, SINE, 0.05, 0.6, f1 * 2.0, f1 * 2.02, 0.4, Vector4(0.1, 0.2, 0.3, 0.2), r)
		au_tremolo(sh, 14.0, 0.8)
		au_mix(b, sh, 0.0, 0.5)
	elif colour == 3:  ## banish: a hollow thud as it goes
		au_voice(b, SINE, 0.3, 0.3, 90.0, 38.0, 0.7, Vector4(0.004, 0.1, 0.0, 0.12), r)
	elif colour == 4:  ## summon: two knocks on the wood
		for k: int in range(2):
			au_voice(b, SINE, 0.3 + 0.12 * float(k), 0.08, 190.0, 120.0, 0.6, Vector4(0.002, 0.03, 0.0, 0.04), r)
			au_voice(b, NOISE, 0.3 + 0.12 * float(k), 0.02, 0.0, 0.0, 0.4, Vector4(0.001, 0.008, 0.0, 0.01), r, 0.25)
	else:  ## seal: a wax press, then silence
		au_voice(b, NOISE, 0.3, 0.1, 0.0, 0.0, 0.5, Vector4(0.01, 0.04, 0.0, 0.05), r, 0.1)
		au_voice(b, SINE, 0.3, 0.2, 70.0, 45.0, 0.7, Vector4(0.005, 0.08, 0.0, 0.1), r)
	au_lowpass(b, 0.45)
	return au_finish(b, SFX_PEAK)


static func cast_scry(r: RandomNumberGenerator) -> AudioStreamWAV:
	return _cast(r, 392.0, 523.0, 0)


static func cast_hex(r: RandomNumberGenerator) -> AudioStreamWAV:
	return _cast(r, 196.0, 147.0, 1)


static func cast_glamour(r: RandomNumberGenerator) -> AudioStreamWAV:
	return _cast(r, 330.0, 440.0, 2)


static func cast_banish(r: RandomNumberGenerator) -> AudioStreamWAV:
	return _cast(r, 262.0, 131.0, 3)


static func cast_summon(r: RandomNumberGenerator) -> AudioStreamWAV:
	return _cast(r, 220.0, 294.0, 4)


static func cast_seal(r: RandomNumberGenerator) -> AudioStreamWAV:
	return _cast(r, 175.0, 165.0, 5)


## A spell turning on you: a flat, dissonant low cluster and a crack.
static func backfire(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.8)
	var cl: PackedFloat32Array = au_buf(0.8)
	var notes: PackedFloat32Array = [50.0, 51.0, 56.0]
	for n: float in notes:
		au_voice(cl, SAW, 0.0, 0.75, au_hz(n), au_hz(n) * 0.95, 0.4, Vector4(0.01, 0.4, 0.4, 0.3), r)
	au_lowpass(cl, 0.15)
	au_mix(b, cl, 0.0, 2.0)
	au_voice(b, NOISE, 0.0, 0.12, 0.0, 0.0, 0.7, Vector4(0.001, 0.04, 0.0, 0.05), r, 0.4)
	au_voice(b, SINE, 0.0, 0.25, 100.0, 40.0, 0.7, Vector4(0.002, 0.08, 0.0, 0.1), r)
	return au_finish(b, SFX_PEAK)


## A page found: a dry paper rustle and one soft bell.
static func found_page(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.7)
	for k: int in range(5):
		au_voice(b, NOISE, 0.06 * float(k), 0.05, 0.0, 0.0, 0.3 + 0.2 * r.randf(), Vector4(0.005, 0.02, 0.0, 0.02), r, 0.35)
	au_bell(b, r, 0.3, au_hz(79.0), 0.4, 0.25)
	au_lowpass(b, 0.6)
	return au_finish(b, SFX_PEAK)


## A curio found: brass clink and a warm two-note bell.
static func found_curio(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.9)
	au_voice(b, NOISE, 0.0, 0.01, 0.0, 0.0, 0.5, Vector4(0.001, 0.004, 0.0, 0.005), r, 0.7)
	au_bell(b, r, 0.02, au_hz(76.0), 0.8, 0.35)
	au_bell(b, r, 0.14, au_hz(83.0), 0.7, 0.3)
	au_lowpass(b, 0.7)
	return au_finish(b, SFX_PEAK)


## A hint whispered: three breathy syllables, quiet.
static func found_hint(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.9)
	var w: PackedFloat32Array = au_buf(0.9)
	var starts: PackedFloat32Array = [0.0, 0.25, 0.5]
	for k: int in range(3):
		au_voice(w, NOISE, starts[k], 0.22, 0.0, 0.0, 0.8, Vector4(0.06, 0.1, 0.4, 0.1), r, 0.3)
	au_tremolo(w, 7.0, 0.5)
	au_mix(b, w, 0.0, 1.0)
	au_voice(b, SINE, 0.0, 0.8, 520.0, 470.0, 0.05, Vector4(0.2, 0.3, 0.3, 0.3), r)
	au_lowpass(b, 0.5)
	return au_finish(b, 0.3)


## Knucklebone dice tumbling on wood.
static func dice_roll(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.7)
	var t: float = 0.0
	for k: int in range(7):
		var amp: float = 0.8 - 0.08 * float(k)
		au_voice(b, SINE, t, 0.05, 260.0 + 80.0 * r.randf(), 140.0, 0.6 * amp, Vector4(0.001, 0.015, 0.0, 0.02), r)
		au_voice(b, NOISE, t, 0.015, 0.0, 0.0, 0.5 * amp, Vector4(0.001, 0.005, 0.0, 0.006), r, 0.3)
		t += 0.04 + 0.012 * float(k) + 0.02 * r.randf()
	return au_finish(b, SFX_PEAK)


static func card_deal(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.16)
	au_voice(b, NOISE, 0.0, 0.14, 0.0, 0.0, 0.6, Vector4(0.01, 0.05, 0.0, 0.07), r, 0.35)
	return au_finish(b, 0.4)


static func card_flip(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.2)
	au_voice(b, NOISE, 0.0, 0.07, 0.0, 0.0, 0.4, Vector4(0.03, 0.03, 0.0, 0.03), r, 0.4)
	au_voice(b, NOISE, 0.09, 0.02, 0.0, 0.0, 0.7, Vector4(0.001, 0.008, 0.0, 0.01), r, 0.3)
	au_voice(b, SINE, 0.09, 0.08, 420.0, 280.0, 0.2, Vector4(0.002, 0.03, 0.0, 0.04), r)
	return au_finish(b, 0.4)


static func wheel_tick(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.05)
	au_voice(b, NOISE, 0.0, 0.012, 0.0, 0.0, 0.6, Vector4(0.0005, 0.004, 0.0, 0.005), r, 0.35)
	au_voice(b, SINE, 0.0, 0.04, 700.0, 500.0, 0.4, Vector4(0.001, 0.01, 0.0, 0.02), r)
	return au_finish(b, 0.35)


static func wheel_settle(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.6)
	au_voice(b, NOISE, 0.0, 0.02, 0.0, 0.0, 0.6, Vector4(0.0005, 0.006, 0.0, 0.008), r, 0.35)
	au_voice(b, SINE, 0.0, 0.2, 320.0, 180.0, 0.6, Vector4(0.001, 0.05, 0.0, 0.08), r)
	au_bell(b, r, 0.03, au_hz(67.0), 0.5, 0.2)
	au_voice(b, SINE, 0.0, 0.2, 90.0, 55.0, 0.5, Vector4(0.003, 0.06, 0.0, 0.08), r)
	return au_finish(b, SFX_PEAK)


## A pair found: two warm bell notes a third apart.
static func pairs_match(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.7)
	au_bell(b, r, 0.0, au_hz(72.0), 0.6, 0.4)
	au_bell(b, r, 0.12, au_hz(76.0), 0.55, 0.4)
	au_lowpass(b, 0.7)
	return au_finish(b, SFX_PEAK)


static func pairs_miss(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.4)
	au_voice(b, SINE, 0.0, 0.3, 170.0, 120.0, 0.7, Vector4(0.003, 0.1, 0.0, 0.12), r)
	au_voice(b, NOISE, 0.0, 0.05, 0.0, 0.0, 0.4, Vector4(0.002, 0.02, 0.0, 0.02), r, 0.2)
	return au_finish(b, SFX_PEAK)


static func stake_win(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.8)
	au_voice(b, NOISE, 0.0, 0.01, 0.0, 0.0, 0.5, Vector4(0.001, 0.004, 0.0, 0.005), r, 0.7)
	au_bell(b, r, 0.0, au_hz(74.0), 0.7, 0.35)
	au_bell(b, r, 0.1, au_hz(79.0), 0.65, 0.3)
	au_bell(b, r, 0.2, au_hz(86.0), 0.6, 0.2)
	au_lowpass(b, 0.7)
	return au_finish(b, SFX_PEAK)


static func stake_lose(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.8)
	au_organ(b, r, 0.0, 0.7, au_hz(52.0), 0.5, au_hz(49.0))
	au_voice(b, NOISE, 0.0, 0.08, 0.0, 0.0, 0.4, Vector4(0.002, 0.03, 0.0, 0.03), r, 0.25)
	au_lowpass(b, 0.25)
	return au_finish(b, SFX_PEAK)


## A lot unwrapped: paper and twine, then a wooden knock.
static func lot_unwrap(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.7)
	for k: int in range(7):
		au_voice(b, NOISE, 0.05 * float(k) + 0.02 * r.randf(), 0.04, 0.0, 0.0, 0.3 + 0.3 * r.randf(),
				Vector4(0.003, 0.015, 0.0, 0.015), r, 0.3)
	au_voice(b, NOISE, 0.4, 0.015, 0.0, 0.0, 0.6, Vector4(0.001, 0.005, 0.0, 0.006), r, 0.4)  ## twine snaps
	au_voice(b, SINE, 0.5, 0.15, 200.0, 110.0, 0.5, Vector4(0.002, 0.05, 0.0, 0.06), r)
	return au_finish(b, SFX_PEAK)


## The Midnight Table opens: a low organ chord (A minor, wide) swelling in.
static func table_open(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.3)
	var notes: PackedFloat32Array = [33.0, 40.0, 48.0, 52.0]
	for n: float in notes:
		au_organ(b, r, 0.0, 1.25, au_hz(n), 0.4, au_hz(n) * 1.003)
	au_lowpass(b, 0.2)
	return au_finish(b, STINGER_PEAK)


static func request_pinned(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.25)
	au_voice(b, SINE, 0.0, 0.1, 240.0, 130.0, 0.7, Vector4(0.001, 0.03, 0.0, 0.05), r)
	au_voice(b, NOISE, 0.0, 0.012, 0.0, 0.0, 0.5, Vector4(0.0005, 0.004, 0.0, 0.005), r, 0.4)
	au_voice(b, SINE, 0.08, 0.14, 1400.0, 1400.0, 0.08, Vector4(0.001, 0.05, 0.0, 0.07), r)  ## the pin rings
	return au_finish(b, SFX_PEAK)


## A rubber stamp: a heavy thud, a paper slap, a small bell.
static func request_done(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.6)
	au_voice(b, SINE, 0.0, 0.18, 130.0, 55.0, 0.9, Vector4(0.002, 0.05, 0.0, 0.08), r)
	au_voice(b, NOISE, 0.0, 0.06, 0.0, 0.0, 0.6, Vector4(0.001, 0.02, 0.0, 0.03), r, 0.25)
	au_bell(b, r, 0.12, au_hz(79.0), 0.45, 0.25)
	return au_finish(b, SFX_PEAK)


## A paper tear: a ripping noise sweep with a ragged crackle, then a low sigh.
static func request_failed(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.6)
	var t: PackedFloat32Array = au_buf(0.35)
	au_voice(t, NOISE, 0.0, 0.33, 0.0, 0.0, 0.8, Vector4(0.02, 0.15, 0.3, 0.1), r, 0.5)
	au_tremolo(t, 38.0, 0.8)
	au_mix(b, t, 0.0, 1.0)
	au_voice(b, SINE, 0.25, 0.3, 150.0, 85.0, 0.4, Vector4(0.01, 0.1, 0.0, 0.15), r)
	au_lowpass(b, 0.55)
	return au_finish(b, SFX_PEAK)


## An omen card turned: a flip and a faint far bell.
static func omen_flip(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.6)
	au_voice(b, NOISE, 0.0, 0.1, 0.0, 0.0, 0.4, Vector4(0.04, 0.04, 0.0, 0.04), r, 0.35)
	au_voice(b, NOISE, 0.11, 0.02, 0.0, 0.0, 0.6, Vector4(0.001, 0.008, 0.0, 0.01), r, 0.3)
	au_bell(b, r, 0.12, au_hz(69.0), 0.45, 0.2)
	au_lowpass(b, 0.6)
	return au_finish(b, SFX_PEAK)


## The Collector arrives: a slow low bell toll over a minor-second organ drone that never resolves.
static func collector_arrive(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	var drone: PackedFloat32Array = au_buf(1.5)
	au_organ(drone, r, 0.0, 1.45, au_hz(38.0), 0.4, au_hz(38.0))
	au_organ(drone, r, 0.3, 1.15, au_hz(39.0), 0.3, au_hz(39.0))
	au_lowpass(drone, 0.2)
	au_mix(b, drone, 0.0, 2.0)
	au_bell(b, r, 0.05, au_hz(50.0), 1.4, 0.5)
	au_bell(b, r, 0.7, au_hz(45.0), 0.75, 0.4)
	au_voice(b, NOISE, 0.0, 1.2, 0.0, 0.0, 0.1, Vector4(0.6, 0.3, 0.5, 0.4), r, 0.05)
	return au_finish(b, STINGER_PEAK)


## He is pleased: the motif lifts a third and rests, a glimmer of brass.
static func collector_pleased(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.2)
	au_organ(b, r, 0.0, 1.1, au_hz(38.0), 0.4, au_hz(38.0))
	au_organ(b, r, 0.2, 0.95, au_hz(42.0), 0.3, au_hz(42.0))
	au_lowpass(b, 0.2)
	au_bell(b, r, 0.0, au_hz(50.0), 1.0, 0.3)
	au_bell(b, r, 0.35, au_hz(66.0), 0.8, 0.3)
	return au_finish(b, STINGER_PEAK)


## He is not: a tritone sinking, two knocks and a cold hiss.
static func collector_refused(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.3)
	var d: PackedFloat32Array = au_buf(1.3)
	au_voice(d, SAW, 0.0, 1.2, au_hz(45.0), au_hz(39.0), 0.4, Vector4(0.02, 0.6, 0.4, 0.4), r)
	au_voice(d, SAW, 0.0, 1.2, au_hz(51.0), au_hz(44.0), 0.3, Vector4(0.02, 0.6, 0.4, 0.4), r)
	au_lowpass(d, 0.12)
	au_mix(b, d, 0.0, 2.5)
	for k: int in range(2):
		au_voice(b, SINE, 0.5 + 0.25 * float(k), 0.12, 150.0, 70.0, 0.7, Vector4(0.002, 0.04, 0.0, 0.06), r)
		au_voice(b, NOISE, 0.5 + 0.25 * float(k), 0.02, 0.0, 0.0, 0.4, Vector4(0.001, 0.008, 0.0, 0.01), r, 0.25)
	au_voice(b, NOISE, 0.1, 0.9, 0.0, 0.0, 0.08, Vector4(0.2, 0.3, 0.3, 0.4), r, 0.3)
	return au_finish(b, STINGER_PEAK)


## An altar purchase: a candle catching, then a warm bell.
static func altar_buy(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.9)
	au_voice(b, NOISE, 0.0, 0.2, 0.0, 0.0, 0.5, Vector4(0.08, 0.06, 0.2, 0.08), r, 0.25)
	au_bell(b, r, 0.1, au_hz(67.0), 0.8, 0.4)
	au_bell(b, r, 0.25, au_hz(74.0), 0.65, 0.3)
	au_lowpass(b, 0.6)
	return au_finish(b, SFX_PEAK)


## A haunting unlocked: a deep bell, its shimmer, and a breath.
static func haunt_unlock(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.4)
	au_bell(b, r, 0.0, au_hz(48.0), 1.3, 0.6)
	au_bell(b, r, 0.0, au_hz(60.0), 1.1, 0.25)
	var sh: PackedFloat32Array = au_buf(1.4)
	au_voice(sh, NOISE, 0.1, 1.2, 0.0, 0.0, 0.6, Vector4(0.3, 0.4, 0.2, 0.5), r, 0.2)
	au_tremolo(sh, 5.0, 0.6)
	au_mix(b, sh, 0.0, 0.3)
	return au_finish(b, STINGER_PEAK)


## A deed earned: a wax-seal thump, then a quill scratching a name.
static func deed(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.8)
	au_voice(b, SINE, 0.0, 0.2, 110.0, 45.0, 0.9, Vector4(0.002, 0.06, 0.0, 0.08), r)
	au_voice(b, NOISE, 0.0, 0.05, 0.0, 0.0, 0.5, Vector4(0.001, 0.015, 0.0, 0.02), r, 0.2)
	var q: PackedFloat32Array = au_buf(0.8)
	for k: int in range(5):
		var t0: float = 0.27 + 0.085 * float(k)
		au_voice(q, NOISE, t0, 0.07, 0.0, 0.0, 0.5, Vector4(0.01, 0.03, 0.0, 0.03), r, 0.7 - 0.08 * float(k % 2))
	au_mix(b, q, 0.0, 0.3)
	return au_finish(b, SFX_PEAK)


## A regular walks in: a soft, warm two-note bell.
static func regular(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.9)
	au_bell(b, r, 0.0, au_hz(72.0), 0.7, 0.35)
	au_bell(b, r, 0.18, au_hz(76.0), 0.65, 0.3)
	au_lowpass(b, 0.45)
	return au_finish(b, SFX_PEAK)


# ---------------------------------------------------------------- full game run: curses, events, wakes, moods, endings

## A held object changes category: three bell ticks that slide, then a soft card-shuffle rasp.
static func curse_shift(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.9)
	for k: int in range(3):
		au_bell(b, r, 0.12 * float(k), au_hz(76.0 - 3.0 * float(k)), 0.4, 0.3)
	var sh: PackedFloat32Array = au_buf(0.5)
	au_voice(sh, SINE, 0.0, 0.5, 900.0, 500.0, 0.5, Vector4(0.1, 0.2, 0.2, 0.2), r)
	au_tremolo(sh, 18.0, 0.8)
	au_mix(b, sh, 0.3, 0.4)
	au_voice(b, NOISE, 0.35, 0.3, 0.0, 0.0, 0.25, Vector4(0.02, 0.1, 0.0, 0.15), r, 0.35)
	return au_finish(b, SFX_PEAK)


## A curse copies itself onto a new object: a bell and its echo a half step flat, hollow.
static func curse_copied(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.4)
	au_bell(b, r, 0.0, au_hz(69.0), 0.9, 0.5)
	au_bell(b, r, 0.22, au_hz(68.0), 0.9, 0.35)
	au_bell(b, r, 0.44, au_hz(67.0), 0.9, 0.2)
	au_voice(b, SINE, 0.0, 0.3, 120.0, 70.0, 0.5, Vector4(0.004, 0.1, 0.0, 0.15), r)
	return au_finish(b, SFX_PEAK)


## A customer is whispered away at the door: breathy, formant-ish noise that fades while a faint voice falls.
static func whispered_away(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.3)
	for k: int in range(3):
		au_voice(b, NOISE, 0.25 * float(k), 0.4, 0.0, 0.0, 0.5 - 0.12 * float(k), Vector4(0.12, 0.15, 0.2, 0.2), r, 0.3 - 0.06 * float(k))
	au_voice(b, SINE, 0.1, 1.0, 420.0, 300.0, 0.12, Vector4(0.3, 0.3, 0.3, 0.5), r)
	au_tremolo(b, 7.0, 0.5)
	return au_finish(b, SFX_PEAK)


## Blackout: a switch-off clunk and a falling hum.
static func event_blackout(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.3)
	au_voice(b, SINE, 0.0, 1.2, 120.0, 30.0, 0.8, Vector4(0.003, 0.6, 0.0, 0.5), r)
	au_voice(b, SQUARE, 0.0, 0.9, 60.0, 20.0, 0.3, Vector4(0.003, 0.3, 0.0, 0.4), r, 1.0, 0.3)
	au_voice(b, NOISE, 0.0, 0.05, 0.0, 0.0, 0.8, Vector4(0.001, 0.015, 0.0, 0.03), r, 0.3)
	au_lowpass(b, 0.3)
	return au_finish(b, STINGER_PEAK)


## Storm: far thunder, low rolling noise with a crack at the head.
static func event_storm(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	au_voice(b, NOISE, 0.0, 1.4, 0.0, 0.0, 1.0, Vector4(0.05, 0.9, 0.2, 0.7), r, 0.04)
	au_voice(b, SINE, 0.05, 1.3, 55.0, 32.0, 0.6, Vector4(0.1, 0.6, 0.2, 0.6), r)
	au_voice(b, NOISE, 0.0, 0.08, 0.0, 0.0, 0.9, Vector4(0.001, 0.02, 0.0, 0.05), r, 0.7)
	return au_finish(b, STINGER_PEAK)


## Auction: a gavel (two knocks, wood and a short ring).
static func event_auction(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.0)
	for k: int in range(2):
		var t: float = 0.25 * float(k)
		au_voice(b, SINE, t, 0.1, 260.0, 140.0, 0.8, Vector4(0.001, 0.04, 0.0, 0.05), r)
		au_voice(b, NOISE, t, 0.03, 0.0, 0.0, 0.6, Vector4(0.001, 0.01, 0.0, 0.02), r, 0.4)
	au_bell(b, r, 0.25, au_hz(79.0), 0.7, 0.2)
	return au_finish(b, SFX_PEAK)


## Full moon: a rising glass swell with a low, wolfish glide beneath it.
static func event_fullmoon(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	au_voice(b, SINE, 0.0, 1.4, 392.0, 587.0, 0.5, Vector4(0.7, 0.4, 0.5, 0.5), r)
	au_voice(b, SINE, 0.0, 1.4, 394.0, 590.0, 0.4, Vector4(0.7, 0.4, 0.5, 0.5), r)
	au_voice(b, SINE, 0.2, 1.2, 150.0, 230.0, 0.3, Vector4(0.4, 0.4, 0.5, 0.5), r)
	au_tremolo(b, 5.0, 0.4)
	au_bell(b, r, 1.0, au_hz(86.0), 0.5, 0.2)
	return au_finish(b, STINGER_PEAK)


## Drift: objects slide: a long scrape with a soft wobble.
static func wake_drift(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	au_voice(b, NOISE, 0.0, 1.4, 0.0, 0.0, 0.7, Vector4(0.3, 0.6, 0.3, 0.5), r, 0.1)
	au_voice(b, SAW, 0.0, 1.4, 90.0, 120.0, 0.3, Vector4(0.3, 0.6, 0.3, 0.5), r)
	au_lowpass(b, 0.25)
	au_tremolo(b, 3.0, 0.5)
	return au_finish(b, STINGER_PEAK)


## Topple: a heavy fall, a clatter of smaller things after it.
static func wake_topple(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	au_voice(b, SINE, 0.0, 0.5, 100.0, 35.0, 0.9, Vector4(0.002, 0.18, 0.0, 0.25), r)
	au_voice(b, NOISE, 0.0, 0.25, 0.0, 0.0, 0.9, Vector4(0.001, 0.08, 0.0, 0.15), r, 0.35)
	for k: int in range(9):
		var t: float = 0.35 + float(k) * 0.1 + r.randf() * 0.05
		au_voice(b, SINE, t, 0.1, 400.0 + r.randf() * 1400.0, 300.0, 0.25, Vector4(0.0005, 0.03, 0.0, 0.06), r)
	return au_finish(b, STINGER_PEAK)


## Lights out: a bulb pop, a sagging hum.
static func wake_lights_out(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.2)
	au_voice(b, NOISE, 0.0, 0.03, 0.0, 0.0, 0.9, Vector4(0.0005, 0.01, 0.0, 0.02), r, 0.9)
	au_voice(b, SINE, 0.02, 1.1, 180.0, 40.0, 0.5, Vector4(0.01, 0.5, 0.0, 0.5), r)
	au_voice(b, SINE, 0.02, 1.1, 360.0, 80.0, 0.2, Vector4(0.01, 0.4, 0.0, 0.5), r)
	return au_finish(b, STINGER_PEAK)


## Door lock: a bolt slides home, then a key turns (two metallic knocks).
static func wake_door_lock(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.2)
	au_voice(b, NOISE, 0.0, 0.25, 0.0, 0.0, 0.4, Vector4(0.1, 0.1, 0.2, 0.05), r, 0.25)
	au_voice(b, SINE, 0.28, 0.1, 210.0, 150.0, 0.8, Vector4(0.001, 0.04, 0.0, 0.05), r)
	au_bell(b, r, 0.28, 1400.0, 0.5, 0.25)
	au_voice(b, SINE, 0.5, 0.12, 170.0, 120.0, 0.9, Vector4(0.001, 0.05, 0.0, 0.06), r)
	au_bell(b, r, 0.5, 1100.0, 0.7, 0.3)
	return au_finish(b, STINGER_PEAK)


## Possession: a wavering vocal tone that locks on, a cold breath.
static func wake_possession(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(1.5)
	au_voice(b, SAW, 0.0, 1.4, 160.0, 150.0, 0.3, Vector4(0.4, 0.5, 0.5, 0.5), r)
	au_voice(b, SAW, 0.0, 1.4, 168.0, 160.0, 0.3, Vector4(0.4, 0.5, 0.5, 0.5), r)
	au_tremolo(b, 6.0, 0.6)
	au_lowpass(b, 0.12)
	au_voice(b, NOISE, 0.2, 1.0, 0.0, 0.0, 0.15, Vector4(0.3, 0.3, 0.3, 0.4), r, 0.2)
	return au_finish(b, STINGER_PEAK)


## A nervous customer: quick trembling taps.
static func mood_nervous(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.45)
	for k: int in range(6):
		au_voice(b, SINE, 0.05 * float(k), 0.04, 1300.0 + r.randf() * 200.0, 1200.0, 0.4, Vector4(0.001, 0.015, 0.0, 0.02), r)
	return au_finish(b, SFX_PEAK)


## A greedy customer: a slow purr of coins and a low hum.
static func mood_greedy(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.7)
	au_bell(b, r, 0.0, 2637.0, 0.4, 0.3)
	au_bell(b, r, 0.12, 3136.0, 0.4, 0.3)
	au_voice(b, SINE, 0.0, 0.6, 140.0, 110.0, 0.3, Vector4(0.1, 0.2, 0.3, 0.2), r)
	return au_finish(b, SFX_PEAK)


## A buyer names a price on a shelf object: a single bright desk-bell ring.
static func buyer_offer(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(0.6)
	au_bell(b, r, 0.0, 2093.0, 0.5, 0.5)
	au_voice(b, NOISE, 0.0, 0.01, 0.0, 0.0, 0.2, Vector4(0.001, 0.004, 0.0, 0.004), r)
	return au_finish(b, SFX_PEAK)


## Endings: each a short chord with its own colour. Debt free: warm, a fifth held open.
static func ending_debt_free(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.0)
	var notes: PackedFloat32Array = [57.0, 64.0, 69.0, 73.0]
	for k: int in range(4):
		au_organ(b, r, 0.12 * float(k), 1.7, au_hz(notes[k]), 0.3, au_hz(notes[k]))
	au_bell(b, r, 0.5, au_hz(81.0), 1.3, 0.3)
	au_lowpass(b, 0.3)
	return au_finish(b, STINGER_PEAK)


## The shop is cursed beyond saving: a minor chord sinking, the bell cracked.
static func ending_cursed_shop(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.0)
	au_organ(b, r, 0.0, 1.9, au_hz(45.0), 0.4, au_hz(44.0))
	au_organ(b, r, 0.0, 1.9, au_hz(51.0), 0.3, au_hz(50.0))
	au_bell(b, r, 0.0, au_hz(69.0), 1.5, 0.4)
	au_bell(b, r, 0.02, au_hz(69.4), 1.5, 0.4)
	au_voice(b, NOISE, 0.0, 1.8, 0.0, 0.0, 0.2, Vector4(0.8, 0.4, 0.3, 0.7), r, 0.05)
	au_lowpass(b, 0.3)
	return au_finish(b, STINGER_PEAK)


## The Collector satisfied: his low drone resolves upward, a single brass bell.
static func ending_collector(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.0)
	au_organ(b, r, 0.0, 1.9, au_hz(34.0), 0.5, au_hz(34.0))
	au_organ(b, r, 0.5, 1.4, au_hz(46.0), 0.3, au_hz(46.0))
	au_bell(b, r, 0.9, au_hz(58.0), 1.0, 0.4)
	au_lowpass(b, 0.25)
	return au_finish(b, STINGER_PEAK)


## The regulars' arcs complete: the music-box tune, finished.
static func ending_regulars(r: RandomNumberGenerator) -> AudioStreamWAV:
	var b: PackedFloat32Array = au_buf(2.0)
	var notes: PackedFloat32Array = [76.0, 72.0, 69.0, 71.0, 72.0, 76.0, 81.0]
	for k: int in range(notes.size()):
		au_bell(b, r, 0.22 * float(k), au_hz(notes[k]), 0.5 if k < 6 else 1.2, 0.3)
	au_organ(b, r, 1.3, 0.65, au_hz(57.0), 0.25, au_hz(57.0))
	return au_finish(b, STINGER_PEAK)


## Decodes a 16-bit mono stream to floats (for measuring).
static func au_decode(w: AudioStreamWAV) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(w.data.size() / 2)
	for i: int in range(out.size()):
		out[i] = float(w.data.decode_s16(i * 2)) / 32767.0
	return out
