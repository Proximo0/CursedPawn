class_name SfxPlayer
extends Node
## Plays SfxSynth sounds for run events (docs/core_brief.md). Streams are built lazily on first use, and one more
## sound is warmed per frame after _ready so the web build (single-threaded) never stalls on a big build.
## Scripted runs (tests, captures) keep working but route everything at silence.

const POOL_SIZE: int = 8
const SILENT_DB: float = -80.0
const BIG_SALE: int = 90  ## a sale at or above this price rings the register
const AMBIENT_DB: float = -6.0  ## ambient is already -18 dBFS RMS in the file
const DREAD_MAX_DB: float = -4.0
const DREAD_EASE: float = 2.0  ## per second
const PITCH_JITTER: float = 0.04
const BLIP_DB: float = -18.0  ## speech-bubble typing blips sit well under the other sounds
const TOOL_SOUNDS: Dictionary = {"uv": "uv_lamp", "scale": "scale_clank", "listen": "listen", "touch": "touch"}
const TELL_DELAY_MAX: float = 0.9
## Every event kind in docs/core_brief.md. Kinds with no entry here are a mapping bug (see unit test).
const EVENT_KINDS: PackedStringArray = [
	"night_start", "customer", "inspected", "counter", "left", "bought", "sold", "passed", "wager", "wake",
	"night_end", "run_lost", "run_won", "invalid",
	"cast", "backfire", "found", "found_hint", "dice", "hand_card", "hand_end", "wheel", "pairs_deal", "pairs_flip",
	"pairs_match", "pairs_miss", "pairs_end", "item_staked", "lot", "table_open", "request_done", "request_failed",
	"collector_omen", "collector_arrives", "collector_pleased", "collector_refused",
]
## UI-only sounds, played with ui(kind): the screens call these where no run event exists.
const UI_SOUNDS: Dictionary = {"click": "ui_click", "omen_flip": "omen_flip", "altar_buy": "altar_buy",
	"haunt_unlock": "haunt_unlock", "request_pinned": "request_pinned", "deed": "deed", "regular": "regular"}
const WHEEL_TICKS: PackedFloat32Array = [0.0, 0.1, 0.2, 0.32, 0.46, 0.64, 0.86]  ## slowing, then the settle

var master: float = 1.0  ## linear 0..1
var muted: bool = false
var seed_value: int = 1
var build_ms: float = 0.0  ## total time spent building streams so far
var played: Array[String] = []  ## names started since creation (kept short; for tests and the debug overlay)

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _ambient: AudioStreamPlayer
var _dread: AudioStreamPlayer
var _dread_target: float = 0.0
var _dread_level: float = 0.0
var _pending: Array[Dictionary] = []  ## {t, name, vol_db}
var _warm_i: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(["sfx_player", seed_value])
	for i: int in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_dread = AudioStreamPlayer.new()
	add_child(_ambient)
	add_child(_dread)
	set_process(true)


func _process(delta: float) -> void:
	if _warm_i < SfxSynth.NAMES.size():
		stream_for(SfxSynth.NAMES[_warm_i])
		_warm_i += 1
	var i: int = 0
	while i < _pending.size():
		_pending[i]["t"] = float(_pending[i]["t"]) - delta
		if float(_pending[i]["t"]) <= 0.0:
			play(str(_pending[i]["name"]), float(_pending[i]["vol_db"]))
			_pending.remove_at(i)
		else:
			i += 1
	_dread_level = move_toward(_dread_level, _dread_target, DREAD_EASE * delta)
	_apply_dread()


# ---------------------------------------------------------------- streams

## The stream for a sound name, built on first use and cached. Null for an unknown name.
func stream_for(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	if not SfxSynth.NAMES.has(name):
		return null
	var t0: int = Time.get_ticks_usec()
	var w: AudioStreamWAV = SfxSynth.build(name, seed_value)
	build_ms += float(Time.get_ticks_usec() - t0) / 1000.0
	_streams[name] = w
	return w


## Builds everything now (measuring): for tools and tests. Returns total milliseconds.
func build_all() -> float:
	for name: String in SfxSynth.NAMES:
		stream_for(name)
	_warm_i = SfxSynth.NAMES.size()
	return build_ms


# ---------------------------------------------------------------- playing

func play(name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var w: AudioStreamWAV = stream_for(name)
	if w == null:
		return
	played.append(name)
	if played.size() > 64:
		played.remove_at(0)
	var p: AudioStreamPlayer = _pool[_next]
	for k: int in range(POOL_SIZE):  ## prefer an idle player; otherwise steal the next in turn
		var c: AudioStreamPlayer = _pool[(_next + k) % POOL_SIZE]
		if not c.playing:
			p = c
			break
	_next = (_pool.find(p) + 1) % POOL_SIZE
	p.stream = w
	p.pitch_scale = pitch * (1.0 + (_rng.randf() * 2.0 - 1.0) * PITCH_JITTER)
	p.volume_db = _db(vol_db)
	p.play()


func _queue(name: String, delay: float, vol_db: float = 0.0) -> void:
	_pending.append({"t": delay, "name": name, "vol_db": vol_db})


func _result(win: bool) -> void:
	play("stake_win" if win else "stake_lose")


func _queue_result(win: bool, delay: float) -> void:
	_queue("stake_win" if win else "stake_lose", delay)


func _db(extra: float) -> float:
	if muted or master <= 0.0 or Flags.is_scripted_run():
		return SILENT_DB
	return extra + linear_to_db(master)


## Maps one batch of run events to sounds.
func on_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		var kind: String = str(ev.get("e", ""))
		match kind:
			"night_start":
				play("footsteps", -6.0)
			"customer":
				play("door_bell")
				_queue("footsteps", 0.45, -8.0)
			"inspected":
				var tool_sound: String = str(TOOL_SOUNDS.get(str(ev.get("tool", "")), "ui_click"))
				play(tool_sound)
				if str(ev.get("tell", "")) != "":
					var w: AudioStreamWAV = stream_for(tool_sound)
					var len_s: float = float(w.data.size()) / 2.0 / float(SfxSynth.SR)
					_queue("tell_found", minf(len_s * 0.7, TELL_DELAY_MAX))
			"counter":
				play("haggle_counter")
			"left":
				play("customer_left")
			"bought":
				play("coin_clink")
			"sold":
				if bool(ev.get("imposter", false)):
					play("wrong_note")
				else:
					play("coin_clink")
					if int(ev.get("price", 0)) >= BIG_SALE:
						_queue("cash_register", 0.2)
			"passed":
				play("footsteps", -9.0)
			"wager":
				play("tarot_flip")
				var win: bool = int(ev.get("payout", 0)) > int(ev.get("stake", 0))
				_queue("tarot_win" if win else "tarot_lose", 0.45)
			"wake":
				play("wake")
			"night_end":
				play("night_end")
			"run_lost":
				play("run_lost")
			"run_won":
				play("run_won")
			"invalid":
				play("wrong_note", -10.0)
			"cast":
				if bool(ev.get("ok", false)):
					var spell_sound: String = "cast_" + str(ev.get("spell", ""))
					play(spell_sound if SfxSynth.NAMES.has(spell_sound) else "cast_scry")
			"backfire":
				play("backfire")
			"found":
				play("found_page" if str(ev.get("kind", "")) == "page" else "found_curio")
			"found_hint":
				play("found_hint", -4.0)
			"dice":
				play("dice_roll")
				_queue_result(int(ev.get("payout", 0)) > int(ev.get("stake", 0)), 0.75)
			"hand_card":
				play("card_deal")
			"hand_end":
				_result(bool(ev.get("win", false)))
			"wheel":
				play("wheel_tick", -4.0)
				for k: int in range(1, WHEEL_TICKS.size()):
					_queue("wheel_tick", WHEEL_TICKS[k], -4.0 - float(k) * 0.5)
				_queue("wheel_settle", WHEEL_TICKS[WHEEL_TICKS.size() - 1] + 0.15)
				if int(ev.get("payout", 0)) > int(ev.get("stake", 0)):
					_queue("pairs_match", 1.2, -4.0)
			"pairs_deal":
				play("card_deal")
			"pairs_flip":
				play("card_flip")
			"pairs_match":
				play("pairs_match")
			"pairs_miss":
				play("pairs_miss")
			"pairs_end":
				_result(int(ev.get("payout", 0)) > int(ev.get("stake", 0)))
			"item_staked":
				_result(bool(ev.get("win", false)))
			"lot":
				play("lot_unwrap")
			"table_open":
				play("table_open", -3.0)
			"request_done":
				play("request_done")
			"request_failed":
				play("request_failed")
			"collector_omen":
				play("collector_arrive", -9.0)
			"collector_arrives":
				play("collector_arrive")
			"collector_pleased":
				play("collector_pleased")
			"collector_refused":
				play("collector_refused")


## UI feedback: "click", "hover", or a UI_SOUNDS kind (omen_flip, altar_buy, haunt_unlock, request_pinned, deed, regular).
func ui(kind: String) -> void:
	if kind == "hover":
		play("ui_hover", -6.0)
	elif UI_SOUNDS.has(kind):
		play(str(UI_SOUNDS[kind]))


## A soft typing blip for one letter of a speech bubble; `pitch` comes from the room bubble.
func blip(pitch: float) -> void:
	play("ui_hover", BLIP_DB, clampf(pitch, 0.5, 2.0))


## Starts the ambient bed (loops until stop_ambient).
func start_ambient() -> void:
	_ambient.stream = stream_for("ambient")
	_ambient.volume_db = _db(AMBIENT_DB)
	_ambient.play()
	_dread.stream = stream_for("dread")
	_apply_dread()


func stop_ambient() -> void:
	_ambient.stop()
	_dread.stop()


## Dread layer volume from 0..1 (the game's Dread over its wake threshold). Eases towards the target.
func set_dread(norm: float) -> void:
	_dread_target = clampf(norm, 0.0, 1.0)


func set_muted(on: bool) -> void:
	muted = on
	_apply_dread()
	_ambient.volume_db = _db(AMBIENT_DB)


func set_master_volume(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	_apply_dread()
	_ambient.volume_db = _db(AMBIENT_DB)


func _apply_dread() -> void:
	if _dread == null:
		return
	var curve: float = pow(_dread_level, 1.5)
	var db: float = SILENT_DB if curve <= 0.01 else _db(lerpf(-30.0, DREAD_MAX_DB, curve))
	_dread.volume_db = db
	if _dread.stream != null and _ambient.playing and not _dread.playing:
		_dread.play()
