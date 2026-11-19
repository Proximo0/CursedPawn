class_name UiTable
extends RefCounted
## The Midnight Table screen (shown in PHASE_TABLE): dark green-black felt, a croupier, a stake picker, the games
## (dice high/low, the hand, the wheel, Tarot Pairs), staking a held item, a sealed lot and leaving. Results are
## animated from the run events: dice tumble, cards flip in one by one, the wheel spins and slows onto its segment,
## Tarot Pairs cards flip with a squash (matches glow and float up, misses shudder and flip back), coins fly on a win
## and a loss smokes away. Results land after their animation (a small timeline), not when the event arrives.
## Widgets: t_dice_high t_dice_low t_hand t_draw t_stand t_wheel t_pairs t_item t_lot t_leave t_stake_dec t_stake_inc
## t_stake_max, "pair:<i>" and (through UiSpellBar.draw_chips) "pick:<uid>". ShopGame turns them into commands.

const STAGE := Rect2(104.0, 22.0, 530.0, 204.0)
const SIDE := Rect2(6.0, 22.0, 92.0, 204.0)
const CTRL := Rect2(104.0, 232.0, 530.0, 72.0)
const PICKER := Rect2(104.0, 150.0, 530.0, 78.0)
const WHEEL_C := Vector2(500.0, 98.0)
const WHEEL_R: float = 58.0
const WHEEL_SECS: float = 3.2
const DICE_SECS: float = 0.95
const FLIP_SECS: float = 0.3
const CARD_GAP: float = 0.42
const PAIRS_CELL := Vector2(36.0, 48.0)
const PAIRS_ORIGIN := Vector2(150.0, 66.0)
const MISS_BEAT: float = 0.55
const SEG_COLS: Array[int] = [2, 5, 12, 6, 3, 8]
const CASH_TARGET := Vector2(52.0, 196.0)

var sfx: SfxPlayer
var stake: int = 1
var games_left: int = 0
var lots_left: int = 0
var night: int = 0
var hand_active: bool = false
var picker_open: bool = false
var pairs_active: bool = false
var pairs_tries: int = 0
var pairs_mult: float = 0.0
var pairs_voided: bool = false
var stage: String = ""
var banner: Dictionary = {}  ## {text, col, age}
var wheel_angle: float = 0.0
var croupier_mood: String = ""  ## "win" / "lose" briefly
var shown_cash: int = -1

var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _later: Array[Dictionary] = []  ## {at, kind, data}
var _dice: Dictionary = {}
var _hand: Array[Dictionary] = []  ## {who, card, total, born}
var _hand_last_born: float = 0.0
var _pairs: Array[Dictionary] = []  ## {state, name, flip_t, dir, shake_t, float_t, glow}
var _wheel_from: float = 0.0
var _wheel_t0: float = -99.0
var _wheel_target: int = -1
var _wheel_edges: PackedFloat32Array = PackedFloat32Array()
var _segs: Array[Dictionary] = []
var _wheel_prev_seg: int = -1
var _kick: float = 0.0
var _coins: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _staked: Dictionary = {}  ## the item-flip animation {name, win, value, age}
var _lot: Dictionary = {}  ## the parcel animation {name, price, hidden, age}
var _croupier_age: float = 0.0
var _tex: Dictionary = {}
var _frames: Array[ImageTexture] = []
var _frames_checked: bool = false


func _init() -> void:
	_rng.seed = 20261119
	_segs = UiOccult.wheel_segments()
	_wheel_edges = UiOccult.wheel_edges(_segs)


# ---------------------------------------------------------------- events

func _at(delay: float, kind: String, data: Dictionary = {}) -> void:
	_later.append({"at": _t + delay, "kind": kind, "data": data})


func _snd(kind: String) -> void:
	if sfx != null:
		sfx.ui(kind)


## Feeds one batch of run events. Table events start animations; everything else is ignored.
func feed(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match str(e.get("e", "")):
			"table_open":
				night = int(e.get("night", night))
				games_left = int(e.get("games_left", 0))
				lots_left = int(e.get("lots_left", 0))
				reset_stage()
			"table_leave":
				reset_stage()
			"dice":
				_on_dice(e)
			"hand_card":
				_on_hand_card(e)
			"hand_end":
				hand_active = false
				var net: int = int(e.get("payout", 0)) - int(e.get("stake", 0))
				_at(maxf(_hand_last_born - _t, 0.0) + FLIP_SECS + 0.35, "result", {"win": bool(e.get("win", false)), "net": net,
					"text": "YOU %d  HOUSE %d" % [int(e.get("you", 0)), int(e.get("house", 0))]})
				games_left = maxi(games_left - 1, 0)
			"pairs_deal":
				_on_pairs_deal(e)
			"pairs_flip":
				_on_pairs_flip(e)
			"pairs_match":
				_on_pairs_match(e)
			"pairs_miss":
				_on_pairs_miss(e)
			"pairs_end":
				_on_pairs_end(e)
			"wheel":
				_on_wheel(e)
			"item_staked":
				_on_item(e)
			"lot":
				_on_lot(e)


func reset_stage() -> void:
	stage = ""
	hand_active = false
	pairs_active = false
	picker_open = false
	banner = {}
	_dice = {}
	_hand.clear()
	_pairs.clear()
	_staked = {}
	_lot = {}
	_later.clear()
	_hand_last_born = 0.0


func _on_dice(e: Dictionary) -> void:
	stage = "dice"
	_dice = {"d1": int(e.get("d1", 1)), "d2": int(e.get("d2", 1)), "age": 0.0, "bounce": 0}
	banner = {}
	games_left = maxi(games_left - 1, 0)
	var net: int = int(e.get("payout", 0)) - int(e.get("stake", 0))
	_at(DICE_SECS + 0.12, "result", {"win": bool(e.get("win", false)), "net": net,
		"text": "YOU CALLED " + str(e.get("call", "")).to_upper()})


func _on_hand_card(e: Dictionary) -> void:
	if stage != "hand":
		_hand.clear()
		banner = {}
	stage = "hand"
	hand_active = true
	var born: float = maxf(_t, _hand_last_born + CARD_GAP)
	_hand_last_born = born
	_hand.append({"who": str(e.get("who", "you")), "card": e.get("card", "?"), "total": int(e.get("total", 0)), "born": born, "snd": false})


func _on_pairs_deal(e: Dictionary) -> void:
	stage = "pairs"
	pairs_active = true
	pairs_tries = int(e.get("tries", 0))
	pairs_mult = 0.0
	pairs_voided = false
	banner = {}
	_pairs.clear()
	for i: int in range(int(e.get("count", 10))):
		_pairs.append({"state": "down", "name": "", "flip_t": -1.0, "dir": 0, "shake_t": -1.0, "float_t": -1.0, "i": i})
	games_left = maxi(games_left - 1, 0)


func _on_pairs_flip(e: Dictionary) -> void:
	var i: int = int(e.get("i", -1))
	if i < 0 or i >= _pairs.size():
		return
	var c: Dictionary = _pairs[i]
	c["name"] = str(e.get("name", e.get("card", "")))
	c["state"] = "up"
	c["flip_t"] = 0.0
	c["dir"] = 1
	_snd("hover")


func _open_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _pairs:
		if str(c["state"]) == "up":
			out.append(c)
	return out


func _on_pairs_match(e: Dictionary) -> void:
	var nm: String = str(e.get("name", e.get("card", "")))
	var mult: float = float(e.get("mult", 0.0))
	pairs_tries = maxi(pairs_tries - 1, 0)
	if nm.to_lower().contains("death") or str(e.get("card", "")) == "death":
		pairs_voided = true  # Death wipes the winnings so far; later pairs start paying again (MidnightTable.pairs_add)
		pairs_mult = 0.0
	else:
		pairs_voided = false
		pairs_mult += mult * Tuning.shared().pairs_pay_scale
	for c: Dictionary in _open_cards():
		c["state"] = "matched"
		c["float_t"] = -FLIP_SECS  # starts floating once its flip has finished
		c["glow"] = 0.0
	_at(FLIP_SECS, "sound", {"k": "click"})


func _on_pairs_miss(e: Dictionary) -> void:
	pairs_tries = maxi(pairs_tries - 1, 0)
	for k: String in ["a", "b"]:
		var i: int = int(e.get(k, -1))
		if i >= 0 and i < _pairs.size():
			_pairs[i]["shake_t"] = -FLIP_SECS  # shudders once it has turned over
			_at(FLIP_SECS + MISS_BEAT, "flip_back", {"i": i})


func _on_pairs_end(e: Dictionary) -> void:
	pairs_active = false
	var net: int = int(e.get("payout", 0)) - int(e.get("stake", 0))
	_at(0.7, "result", {"win": int(e.get("payout", 0)) > int(e.get("stake", 0)), "net": net,
		"text": "%d PAIR%s FOUND" % [int(e.get("matches", 0)), "" if int(e.get("matches", 0)) == 1 else "S"]})


func _on_wheel(e: Dictionary) -> void:
	stage = "wheel"
	banner = {}
	games_left = maxi(games_left - 1, 0)
	var idx: int = UiOccult.wheel_index(_segs, e)
	if idx < 0:
		idx = 0
	_wheel_from = fposmod(wheel_angle, TAU)
	_wheel_t0 = _t
	_wheel_target = idx
	var net: int = int(e.get("payout", 0)) - int(e.get("stake", 0))
	_at(WHEEL_SECS + 0.1, "result", {"win": net > 0, "net": net, "text": str(e.get("name", "")).to_upper() +
		("  + A %s" % str(e.get("prize", "")).to_upper() if str(e.get("prize", "")) != "" else "")})


func _on_item(e: Dictionary) -> void:
	stage = "item"
	picker_open = false
	banner = {}
	games_left = maxi(games_left - 1, 0)
	_staked = {"name": str(e.get("name", "ITEM")), "win": bool(e.get("win", false)), "value": int(e.get("value", 0)), "age": 0.0}
	_at(1.1, "result", {"win": bool(e.get("win", false)), "net": int(e.get("value", 0)) if bool(e.get("win", false)) else -int(e.get("value", 0)),
		"text": ("THE HOUSE PAYS FOR YOUR " if bool(e.get("win", false)) else "THE HOUSE KEEPS YOUR ") + str(e.get("name", "ITEM")).to_upper()})


func _on_lot(e: Dictionary) -> void:
	stage = "lot"
	banner = {}
	lots_left = maxi(lots_left - 1, 0)
	_lot = {"name": str(e.get("name", "?")), "price": int(e.get("price", 0)), "hidden": bool(e.get("hidden", false)), "age": 0.0}
	_at(1.2, "result", {"win": true, "net": 0, "text": "A LOT OF: " + str(e.get("name", "?")).to_upper(), "coins": false})


# ---------------------------------------------------------------- state and time

func stake_max(r: RunState) -> int:
	var frac: float = float(r.tuning.get("table_max_stake_frac")) if UiOccult.has_prop(r.tuning, "table_max_stake_frac") else 0.5
	return maxi(1, int(floor(float(r.cash) * frac)))


func clamp_stake(r: RunState) -> void:
	stake = clampi(stake, 1, stake_max(r))


func busy() -> bool:
	return not _later.is_empty() or hand_active or pairs_active


func tick(delta: float, r: RunState) -> void:
	_t += delta
	_croupier_age += delta
	if shown_cash < 0:
		shown_cash = r.cash
	clamp_stake(r)
	var i: int = _later.size() - 1
	var due: Array[Dictionary] = []
	while i >= 0:
		if float(_later[i]["at"]) <= _t:
			due.push_front(_later[i])
			_later.remove_at(i)
		i -= 1
	for d: Dictionary in due:
		_fire(d, r)
	if not _dice.is_empty():
		var a0: float = float(_dice["age"])
		_dice["age"] = a0 + delta
		var b: int = int(a0 * 9.0 / PI)
		if a0 < DICE_SECS and int(float(_dice["age"]) * 9.0 / PI) != b:
			_snd("hover")
	if not _staked.is_empty():
		_staked["age"] = float(_staked["age"]) + delta
	if not _lot.is_empty():
		_lot["age"] = float(_lot["age"]) + delta
	if not banner.is_empty():
		banner["age"] = float(banner["age"]) + delta
	for c: Dictionary in _pairs:
		if int(c["dir"]) != 0:
			c["flip_t"] = float(c["flip_t"]) + delta
		for k: String in ["float_t", "shake_t"]:
			if float(c[k]) > -90.0:
				c[k] = float(c[k]) + delta
		if str(c["state"]) == "matched" and float(c["float_t"]) >= 0.0:
			c["glow"] = float(c["float_t"])
	if _wheel_target >= 0:
		var u: float = (_t - _wheel_t0) / WHEEL_SECS
		wheel_angle = UiOccult.wheel_angle(u, _wheel_edges, _wheel_target, 4, _wheel_from)
		var under: int = UiOccult.wheel_under(_wheel_edges, wheel_angle)
		if u < 1.0 and under != _wheel_prev_seg and _wheel_prev_seg >= 0:
			_kick = 0.09
			_snd("hover")
		_wheel_prev_seg = under
	_kick = maxf(_kick - delta, 0.0)
	_tick_fx(delta, r)


func _fire(d: Dictionary, r: RunState) -> void:
	var data: Dictionary = d["data"] as Dictionary
	match str(d["kind"]):
		"result":
			var net: int = int(data.get("net", 0))
			var win: bool = bool(data.get("win", false))
			banner = {"text": str(data.get("text", "")), "col": 7 if win else 13, "age": 0.0, "net": net}
			croupier_mood = "win" if win else "lose"
			_croupier_age = 0.0
			if bool(data.get("coins", true)):
				if net > 0:
					for k: int in range(clampi(net, 3, 12)):
						_coins.append({"from": Vector2(270.0, 110.0), "to": CASH_TARGET, "delay": float(k) * 0.07, "age": 0.0})
					_snd("click")
				elif net < 0 or not win:
					_puff(Vector2(270.0, 118.0), 14)
			shown_cash = r.cash
		"sound":
			_snd(str(data.get("k", "click")))
		"flip_back":
			var c: Dictionary = _pairs[int(data["i"])]
			c["state"] = "down"
			c["flip_t"] = 0.0
			c["dir"] = -1
			c["shake_t"] = -99.0
			_snd("hover")


func _puff(at: Vector2, n: int) -> void:
	for k: int in range(n * 2):
		_smoke.append({"p": at + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-6.0, 6.0)), "age": -_rng.randf() * 0.3,
			"vx": _rng.randf_range(-8.0, 8.0), "life": _rng.randf_range(0.8, 1.4)})


func _tick_fx(delta: float, r: RunState) -> void:
	for c: Dictionary in _coins:
		c["age"] = float(c["age"]) + delta
	while not _coins.is_empty() and float(_coins[0]["age"]) - float(_coins[0]["delay"]) > 0.75:
		_coins.pop_front()
	for s: Dictionary in _smoke:
		s["age"] = float(s["age"]) + delta
		s["p"] = (s["p"] as Vector2) + Vector2(float(s["vx"]) * delta, -22.0 * delta)
	var i: int = _smoke.size() - 1
	while i >= 0:
		if float(_smoke[i]["age"]) > float(_smoke[i]["life"]):
			_smoke.remove_at(i)
		i -= 1
	if _later.is_empty() and shown_cash != r.cash and banner.is_empty():
		shown_cash = r.cash  # nothing pending: the readout follows the run


# ---------------------------------------------------------------- drawing

func draw(hud: UiHud, r: RunState, spell_bar: UiSpellBar, hover: String) -> void:
	_felt(hud)
	_draw_side(hud, r)
	_draw_wheel(hud)
	match stage:
		"dice":
			_draw_dice(hud)
		"hand":
			_draw_hand(hud)
		"pairs":
			_draw_pairs(hud, hover)
		"wheel":
			hud._text_c(250.0, 96.0, "THE WHEEL TURNS...", 11 if int(_t * 4.0) % 2 == 0 else 10)
		"item":
			_draw_item(hud)
		"lot":
			_draw_lot(hud)
		_:
			hud._text_c(250.0, 96.0, "THE HOUSE WAITS.", 6)
			hud._text_c(250.0, 110.0, "PLACE A STAKE, FRIEND.", 5 if int(_t * 2.0) % 2 == 0 else 6)
	_draw_fx(hud)
	_draw_banner(hud)
	_draw_controls(hud, r)
	if picker_open:
		spell_bar.draw_chips(hud, r, PICKER, hover, "STAKE A HELD ITEM: COIN FLIP FOR DOUBLE ITS VALUE")


func _felt(hud: UiHud) -> void:
	hud._rect(Rect2(0.0, 18.0, 640.0, 342.0), 5)
	for k: int in range(110):
		var x: float = UiMotion.ui_hash(k, 1, 77) * 640.0
		var y: float = 18.0 + UiMotion.ui_hash(k, 2, 77) * 342.0
		hud._rect(Rect2(floorf(x), floorf(y), 1.0, 1.0), 0 if k % 3 != 0 else 6)
	# the pool of candlelight on the cloth, then a heavy vignette
	hud.draw_texture_rect(TsCanvas.dim_texture(6), Rect2(0.0, 18.0, 640.0, 60.0), true)
	hud.draw_texture_rect(TsCanvas.dim_texture(8), Rect2(0.0, 300.0, 640.0, 60.0), true)
	hud.draw_texture_rect(TsCanvas.dim_texture(5), Rect2(0.0, 18.0, 70.0, 342.0), true)
	hud.draw_texture_rect(TsCanvas.dim_texture(5), Rect2(570.0, 18.0, 70.0, 342.0), true)
	var rim := Rect2(STAGE.position.x + 2.0, STAGE.position.y + 2.0, STAGE.size.x - 4.0, STAGE.size.y - 4.0 - 24.0)
	hud.draw_rect(rim, hud._c(8), false, 1.0)
	hud.draw_rect(rim.grow(-3.0), hud._c(6), false, 1.0)
	hud._text_c(250.0, 27.0, "THE MIDNIGHT TABLE", 11 if int(_t * 3.0) % 9 != 0 else 10)


func _croupier_tex() -> Array[ImageTexture]:
	if not _frames_checked:
		_frames_checked = true
		var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
		if sk != null and UiOccult.static_has(sk, "croupier_frames"):
			var got: Variant = sk.call("croupier_frames")
			if got is Array:
				for f: Variant in got:
					if f is ImageTexture:
						_frames.append(f as ImageTexture)
	return _frames


func _draw_side(hud: UiHud, r: RunState) -> void:
	hud._frame(SIDE, "panel")
	var cr := Vector2(SIDE.position.x + 14.0, SIDE.position.y + 8.0)
	var bob: float = floorf(sin(_t * 1.7) * 1.0 + 0.5)
	var frames: Array[ImageTexture] = _croupier_tex()
	if not frames.is_empty():
		var fi: int = int(_t * 6.0) % frames.size()
		hud.draw_texture(frames[fi], cr + Vector2(0.0, bob))
	else:
		_placeholder_croupier(hud, cr + Vector2(0.0, bob))
	var gy: float = 122.0
	hud._text(Vector2(12.0, gy), "NIGHT %d" % night, 14)
	hud._text(Vector2(12.0, gy + 12.0), "GAMES", 14)
	_pips(hud, Vector2(50.0, gy + 13.0), games_left, 7)
	hud._text(Vector2(12.0, gy + 24.0), "LOTS", 14)
	_pips(hud, Vector2(50.0, gy + 25.0), lots_left, 11)
	hud._rect(Rect2(12.0, gy + 38.0, 80.0, 1.0), 8)
	hud._text(Vector2(12.0, gy + 46.0), "CASH", 14)
	var spin: float = 9.0 if banner.is_empty() or float(banner.get("age", 9.0)) > 0.5 else float(banner["age"]) / 0.45
	hud._coin(Vector2(20.0, gy + 66.0), spin)
	hud._text(Vector2(30.0, gy + 63.0), "%d" % maxi(shown_cash, 0), 11)


func _pips(hud: UiHud, at: Vector2, n: int, col: int) -> void:
	for k: int in range(clampi(n, 0, 8)):
		hud._rect(Rect2(at.x + float(k) * 5.0, at.y, 3.0, 4.0), col)
	if n <= 0:
		hud._text(Vector2(at.x, at.y - 1.0), "NONE", 13)


## A stand-in croupier until SpriteKit.croupier_frames() exists: a hooded shape with two pinpricks that blink and widen.
func _placeholder_croupier(hud: UiHud, at: Vector2) -> void:
	hud._rect(Rect2(at.x + 10.0, at.y + 16.0, 44.0, 80.0), 1)
	hud._rect(Rect2(at.x + 16.0, at.y + 4.0, 32.0, 34.0), 2)
	hud._rect(Rect2(at.x + 20.0, at.y + 12.0, 24.0, 24.0), 0)
	hud._rect(Rect2(at.x + 12.0, at.y + 44.0, 40.0, 6.0), 3)
	hud._rect(Rect2(at.x + 22.0, at.y + 60.0, 8.0, 10.0), 14)
	hud._rect(Rect2(at.x + 34.0, at.y + 60.0, 8.0, 10.0), 14)
	var blink: bool = fmod(_t, 3.4) < 0.12
	var wide: bool = croupier_mood != "" and _croupier_age < 1.2
	var h: float = 0.0 if blink else (3.0 if wide else 2.0)
	var col: int = 13 if croupier_mood == "lose" and wide else 11
	if h > 0.0:
		hud._rect(Rect2(at.x + 25.0, at.y + 22.0, 2.0, h), col)
		hud._rect(Rect2(at.x + 37.0, at.y + 22.0, 2.0, h), col)


func _draw_wheel(hud: UiHud) -> void:
	var c: Vector2 = WHEEL_C
	hud.draw_circle(c + Vector2(0.0, 3.0), WHEEL_R + 4.0, hud._c(0))
	hud.draw_circle(c, WHEEL_R + 3.0, hud._c(9))
	hud.draw_circle(c, WHEEL_R + 1.0, hud._c(8))
	var n: int = _segs.size()
	for i: int in range(n):
		var a0: float = _wheel_edges[i] + wheel_angle - PI * 0.5
		var a1: float = _wheel_edges[i + 1] + wheel_angle - PI * 0.5
		var pts := PackedVector2Array([c])
		var steps: int = maxi(3, int((a1 - a0) / 0.12))
		for s: int in range(steps + 1):
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(s) / float(steps))) * WHEEL_R)
		var under: bool = _wheel_target >= 0 and (_t - _wheel_t0) > WHEEL_SECS and i == _wheel_target
		var col: int = SEG_COLS[i % SEG_COLS.size()]
		if under and int(_t * 6.0) % 2 == 0:
			col = 10
		hud.draw_colored_polygon(pts, hud._c(col))
		hud.draw_line(c, c + Vector2.from_angle(a0) * WHEEL_R, hud._c(0), 1.0)
		var mid: float = (a0 + a1) * 0.5
		var label: String = str(_segs[i].get("name", "?")).substr(0, 1).to_upper()
		var lp: Vector2 = (c + Vector2.from_angle(mid) * (WHEEL_R * 0.72)).floor()
		hud._text(lp - Vector2(2.0, 3.0), label, 15, 1, true)
		if str(_segs[i].get("prize", "")) != "":
			hud._rect(Rect2((c + Vector2.from_angle(mid) * (WHEEL_R * 0.92)).floor(), Vector2(2.0, 2.0)), 11)
	hud.draw_arc(c, WHEEL_R, 0.0, TAU, 48, hud._c(0), 1.0)
	hud.draw_circle(c, 7.0, hud._c(0))
	hud.draw_circle(c, 5.0, hud._c(10))
	hud.draw_circle(c, 2.0, hud._c(11))
	var py: float = c.y - WHEEL_R - 6.0 + (3.0 if _kick > 0.0 else 0.0)
	hud.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 5.0, py - 2.0), Vector2(c.x + 5.0, py - 2.0), Vector2(c.x, py + 10.0)]), hud._c(0))
	hud.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 3.0, py), Vector2(c.x + 3.0, py), Vector2(c.x, py + 7.0)]), hud._c(11))
	hud._text_c(c.x, c.y + WHEEL_R + 10.0, "THE SOUL WHEEL", 14)


func _die(hud: UiHud, center: Vector2, v: int, squash: float = 0.0) -> void:
	var w: float = 26.0 + squash * 3.0
	var h: float = 26.0 - squash * 4.0
	var rc := Rect2((center - Vector2(w, h) * 0.5).floor(), Vector2(w, h))
	hud._rect(Rect2(rc.position + Vector2(2.0, 3.0), rc.size), 0)
	hud._rect(rc, 14)
	hud._rect(Rect2(rc.position.x + 1.0, rc.position.y + 1.0, rc.size.x - 2.0, rc.size.y - 2.0), 15)
	hud._rect(Rect2(rc.position.x, rc.end.y - 2.0, rc.size.x, 2.0), 14)
	var pips: Dictionary = {1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8]}
	for p: Variant in pips.get(clampi(v, 1, 6), [4]):
		var gx: int = int(p) % 3
		var gy: int = int(p) / 3
		hud._rect(Rect2(rc.position.x + 5.0 + float(gx) * 6.0, rc.position.y + 5.0 + float(gy) * (h - 12.0) * 0.5, 3.0, 3.0), 0)


func _draw_dice(hud: UiHud) -> void:
	var age: float = float(_dice.get("age", 0.0))
	var base := Vector2(222.0, 104.0)
	hud._rect(Rect2(base.x - 52.0, base.y + 22.0, 156.0, 3.0), 0)
	for k: int in range(2):
		var cx: float = base.x + float(k) * 56.0 - 14.0
		var v: int = int(_dice["d%d" % (k + 1)])
		if age < DICE_SECS:
			var u: float = age / DICE_SECS
			var hop: float = absf(sin(age * 9.0 + float(k) * 1.7)) * 46.0 * (1.0 - u)
			var drift: float = sin(age * 13.0 + float(k) * 2.3) * 20.0 * (1.0 - u)
			var face: int = 1 + int(UiMotion.ui_hash(int(age * 16.0), k, 5) * 6.0)
			_die(hud, Vector2(cx + drift, base.y - hop), v if u > 0.92 else face)
		else:
			var sq: float = maxf(1.0 - (age - DICE_SECS) / 0.14, 0.0)
			_die(hud, Vector2(cx, base.y), v, sq)
	if age > DICE_SECS:
		var total: int = int(_dice["d1"]) + int(_dice["d2"])
		hud._text_c(base.x + 14.0, base.y + 32.0, "TOTAL %d" % total, 15)


func _card(hud: UiHud, at: Vector2, label: String, up: float, who_house: bool = false) -> void:
	var f: float = UiOccult.flip_width(up)
	var face: bool = UiOccult.flip_face_up(up)
	var w: float = maxf(floorf(24.0 * f), 2.0)
	var rc := Rect2(at.x + floorf((24.0 - w) * 0.5), at.y, w, 34.0)
	hud._rect(Rect2(rc.position + Vector2(1.0, 2.0), rc.size), 0)
	hud._rect(rc, 0)
	if face:
		hud._rect(Rect2(rc.position + Vector2(1.0, 1.0), rc.size - Vector2(2.0, 2.0)), 15)
		if w > 12.0:
			hud._text_c(rc.get_center().x, rc.position.y + 13.0, label, 12 if not who_house else 0, 2, false)
	else:
		hud._rect(Rect2(rc.position + Vector2(1.0, 1.0), rc.size - Vector2(2.0, 2.0)), 12)
		if w > 8.0:
			hud._rect(Rect2(rc.position.x + 3.0, rc.position.y + 3.0, w - 6.0, 28.0), 11 if int(_t * 2.0) % 2 == 0 else 10)
			hud._rect(Rect2(rc.position.x + 4.0, rc.position.y + 4.0, w - 8.0, 26.0), 12)


func _draw_hand(hud: UiHud) -> void:
	for who: String in ["you", "house"]:
		var y: float = 46.0 if who == "you" else 104.0
		hud._text(Vector2(126.0, y + 4.0), "YOU" if who == "you" else "HOUSE", 11 if who == "you" else 13)
		var x: float = 176.0
		var total: int = 0
		var landed: bool = false
		for c: Dictionary in _hand:
			if str(c["who"]) != who:
				continue
			var age: float = _t - float(c["born"])
			if age < 0.0:
				continue
			var u: float = clampf(age / FLIP_SECS, 0.0, 1.0)
			var lift: float = (1.0 - UiMotion.ui_out(clampf(age / 0.2, 0.0, 1.0))) * -12.0
			_card(hud, Vector2(x, y + lift), str(c["card"]), u, who == "house")
			if not bool(c["snd"]):
				c["snd"] = true
				_snd("hover")
			if u >= 1.0:
				total = int(c["total"])
				landed = true
			x += 30.0
		if landed:
			hud._text(Vector2(126.0, y + 18.0), str(total), 15, 2)


func _draw_pairs(hud: UiHud, hover: String) -> void:
	var back: ImageTexture = _card_tex("", false)
	for c: Dictionary in _pairs:
		var i: int = int(c["i"])
		var pos: Vector2 = UiOccult.pairs_cell(PAIRS_ORIGIN, i, PAIRS_CELL) + Vector2(6.0, 4.0)
		var state: String = str(c["state"])
		var flip: float = float(c["flip_t"])
		var u: float = 1.0 if state == "matched" else 0.0
		if flip >= 0.0 and int(c["dir"]) != 0:
			var k: float = clampf(flip / FLIP_SECS, 0.0, 1.0)
			u = k if int(c["dir"]) > 0 else 1.0 - k
		elif state == "up":
			u = 1.0
		var shake: float = float(c["shake_t"])
		if shake >= 0.0 and shake < 0.5:
			pos.x += UiOccult.shudder(shake / 0.5)
		var glow: bool = false
		if state == "matched" and float(c["float_t"]) >= 0.0:
			var ft: float = float(c["float_t"])
			pos.y -= UiMotion.ui_out(ft / 0.5) * 7.0 + floorf(sin(ft * 3.0) * 1.0)
			glow = true
		var hot: bool = hover == "pair:%d" % i
		if state == "down" and flip < 0.0 or (state == "down" and int(c["dir"]) < 0 and u <= 0.0):
			hud._add("pair:%d" % i, Rect2(pos, Vector2(24.0, 40.0)), pairs_active and _open_cards().size() < 2 and _later_flips() == 0)
			if hot:
				pos.y -= 2.0
		_pair_card(hud, pos, c, u, back, glow)
	hud._text_c(PAIRS_ORIGIN.x + 90.0, PAIRS_ORIGIN.y - 18.0, "TAROT PAIRS: FIND THE TWINS", 11)
	var run_pay: String = "VOID" if pairs_voided else "x%.1f" % pairs_mult
	hud._text_c(PAIRS_ORIGIN.x + 90.0, PAIRS_ORIGIN.y + 104.0, "TRIES %d    PAYS %s" % [pairs_tries, run_pay], 15 if not pairs_voided else 13)
	if pairs_active and _open_cards().is_empty() and int(_t * 2.0) % 2 == 0:
		hud._text_c(PAIRS_ORIGIN.x + 90.0, PAIRS_ORIGIN.y + 116.0, "CLICK A CARD", 14)


func _later_flips() -> int:
	var n: int = 0
	for d: Dictionary in _later:
		if str(d["kind"]) == "flip_back":
			n += 1
	return n


func _card_tex(nm: String, up: bool) -> ImageTexture:
	var key: String = ("u:" + nm) if up else "d"
	if not _tex.has(key):
		_tex[key] = SpriteKit.card_texture(nm, up)
	return _tex[key] as ImageTexture


func _pair_card(hud: UiHud, pos: Vector2, c: Dictionary, u: float, back: ImageTexture, glow: bool) -> void:
	var w: float = maxf(floorf(24.0 * UiOccult.flip_width(u)), 2.0)
	var squash: float = 1.0 - (1.0 - UiOccult.flip_width(u)) * 0.08
	var h: float = floorf(40.0 * squash)
	var rc := Rect2(pos.x + floorf((24.0 - w) * 0.5), pos.y + floorf((40.0 - h) * 0.5), w, h)
	hud._rect(Rect2(pos.x + 2.0, pos.y + 40.0, 22.0, 2.0), 0)
	if glow:
		var pulse: float = 0.5 + 0.5 * sin(float(c["glow"]) * 7.0)
		hud.draw_rect(rc.grow(2.0 + pulse * 2.0), hud._c(11 if pulse > 0.5 else 10), false, 1.0)
		hud.draw_rect(rc.grow(5.0), hud._c(9), false, 1.0)
	var tex: ImageTexture = _card_tex(str(c["name"]), true) if UiOccult.flip_face_up(u) and str(c["name"]) != "" else back
	hud.draw_texture_rect(tex, rc, false)


func _draw_item(hud: UiHud) -> void:
	var age: float = float(_staked.get("age", 0.0))
	var c := Vector2(250.0, 98.0)
	var win: bool = bool(_staked.get("win", false))
	var u: float = clampf(age / 0.9, 0.0, 1.0)
	var coin_w: float = 20.0 * absf(cos(u * TAU * 3.0 * (1.0 - u * 0.5)))
	if u < 1.0:
		hud._rect(Rect2(c.x - coin_w - 1.0, c.y - 21.0 - sin(u * PI) * 30.0, coin_w * 2.0 + 2.0, 42.0), 0)
		hud._rect(Rect2(c.x - coin_w, c.y - 20.0 - sin(u * PI) * 30.0, coin_w * 2.0, 40.0), 10)
	else:
		var col: int = 11 if win else 3
		hud._rect(Rect2(c.x - 21.0, c.y - 21.0, 42.0, 42.0), 0)
		hud._rect(Rect2(c.x - 20.0, c.y - 20.0, 40.0, 40.0), col)
		hud._text_c(c.x, c.y - 4.0, str(_staked.get("name", "")).substr(0, 6).to_upper(), 0, 1, false)
	hud._text_c(c.x, c.y + 34.0, "A COIN FOR YOUR %s" % str(_staked.get("name", "")).to_upper(), 14)


func _draw_lot(hud: UiHud) -> void:
	var age: float = float(_lot.get("age", 0.0))
	var c := Vector2(250.0, 92.0)
	var shake: float = 0.0 if age > 1.0 else roundf(sin(age * 50.0) * 2.0 * (1.0 - age))
	var open: float = clampf((age - 0.9) / 0.3, 0.0, 1.0)
	var p := Vector2(c.x - 22.0 + shake, c.y - 22.0 - open * 12.0)
	hud._rect(Rect2(p.x + 2.0, p.y + 46.0, 44.0, 3.0), 0)
	hud._rect(Rect2(p, Vector2(44.0, 44.0)), 0)
	hud._rect(Rect2(p + Vector2(1.0, 1.0), Vector2(42.0, 42.0)), 9)
	hud._rect(Rect2(p + Vector2(1.0, 1.0), Vector2(42.0, 3.0)), 10)
	hud._rect(Rect2(p.x + 20.0, p.y + 1.0, 4.0, 42.0), 13)
	hud._rect(Rect2(p.x + 1.0, p.y + 20.0, 42.0, 4.0), 13)
	if open > 0.0:
		for k: int in range(8):
			var a: float = float(k) * TAU / 8.0 + age
			var d: float = open * (18.0 + float(k % 3) * 6.0)
			hud._rect(Rect2((c + Vector2.from_angle(a) * d).floor(), Vector2(2.0, 2.0)), 11 if not bool(_lot.get("hidden", false)) or k % 2 == 0 else 4)
	if open >= 1.0 and bool(_lot.get("hidden", false)):
		hud._text_c(c.x, c.y + 36.0, "SOMETHING ELSE RATTLES IN IT...", 4 if int(_t * 6.0) % 2 == 0 else 15)
	hud._text_c(c.x, c.y + 50.0, "SEALED LOT, %d COINS" % int(_lot.get("price", 0)), 14)


func _draw_fx(hud: UiHud) -> void:
	for s: Dictionary in _smoke:
		var a: float = float(s["age"])
		if a < 0.0:
			continue
		var u: float = a / float(s["life"])
		var sz: float = 2.0 + floorf(u * 5.0)
		var col: int = [14, 3, 2, 1][clampi(int(u * 4.0), 0, 3)]
		hud._rect(Rect2((s["p"] as Vector2).floor(), Vector2(sz, sz)), col)
	for c: Dictionary in _coins:
		var a: float = float(c["age"]) - float(c["delay"])
		if a < 0.0:
			continue
		var u: float = clampf(a / 0.7, 0.0, 1.0)
		var from: Vector2 = c["from"] as Vector2
		var to: Vector2 = c["to"] as Vector2
		var p: Vector2 = from.lerp(to, UiMotion.ui_in_out(u)) + Vector2(0.0, -sin(u * PI) * 34.0)
		hud._coin(p.floor(), fmod(a * 2.2, 1.0))


func _draw_banner(hud: UiHud) -> void:
	if banner.is_empty():
		return
	var age: float = float(banner["age"])
	var rise: float = UiMotion.ui_back(age / 0.3)
	var y: float = 150.0 - rise * 4.0
	var net: int = int(banner.get("net", 0))
	var col: int = int(banner["col"])
	var head: String = str(banner["text"])
	hud._text_c(250.0, y, head, 15)
	if net != 0:
		var amount: String = "%+d" % net
		var dw: int = UiPixelFont.ui_head_width(amount, 2)
		UiPixelFont.ui_head_draw(hud, Vector2(250.0 - float(dw) * 0.5, y + 12.0 - (0.0 if age > 0.3 else (0.3 - age) * 20.0)), amount, hud._c(col), 2, true, hud._c(0))


func _draw_controls(hud: UiHud, r: RunState) -> void:
	hud._frame(CTRL, "panel")
	var idle: bool = not busy() and games_left > 0
	var any_game: bool = idle and r.cash >= 1
	var x: float = CTRL.position.x + 8.0
	var y: float = CTRL.position.y + 7.0
	hud._text(Vector2(x, y + 7.0), "STAKE", 14)
	hud._button("t_stake_dec", Rect2(x + 40.0, y, 18.0, 21.0), "-", not busy())
	hud._frame(Rect2(x + 60.0, y, 52.0, 21.0), "btn_off")
	hud._coin(Vector2(x + 69.0, y + 10.0))
	hud._text(Vector2(x + 78.0, y + 7.0), "%d" % stake, 11)
	hud._button("t_stake_inc", Rect2(x + 114.0, y, 18.0, 21.0), "+", not busy())
	hud._button("t_stake_max", Rect2(x + 134.0, y, 34.0, 21.0), "MAX", not busy())
	var gx: float = x + 180.0
	hud._button("t_dice_high", Rect2(gx, y, 62.0, 21.0), "DICE HI", any_game)
	hud._button("t_dice_low", Rect2(gx + 64.0, y, 62.0, 21.0), "DICE LO", any_game)
	hud._button("t_wheel", Rect2(gx + 128.0, y, 62.0, 21.0), "WHEEL", any_game)
	hud._button("t_pairs", Rect2(gx + 192.0, y, 62.0, 21.0), "PAIRS", any_game, true)
	var y2: float = y + 25.0
	if hand_active:
		hud._button("t_draw", Rect2(x, y2, 62.0, 21.0), "DRAW", true, true)
		hud._button("t_stand", Rect2(x + 64.0, y2, 62.0, 21.0), "STAND", true, true)
	else:
		hud._button("t_hand", Rect2(x, y2, 62.0, 21.0), "HAND", any_game)
	hud._button("t_item", Rect2(x + 134.0, y2, 92.0, 21.0), "STAKE ITEM", any_game and not r.inventory.is_empty())
	hud._button("t_lot", Rect2(x + 232.0, y2, 112.0, 21.0), "SEALED LOT", idle and lots_left > 0)
	hud._button("t_leave", Rect2(CTRL.end.x - 106.0, y2, 98.0, 21.0), "LEAVE", not busy() or games_left <= 0, true)
	var hint: String = _hint(r)
	hud._text(Vector2(x, CTRL.end.y - 12.0), hint, 14)


func _hint(r: RunState) -> String:
	if pairs_active:
		return "FLIP TWO CARDS A TRY. A PAIR PAYS ITS CARD. DEATH VOIDS IT ALL."
	if hand_active:
		return "DRAW TO 13. THE HOUSE DRAWS TO 10. GO OVER AND YOU LOSE."
	if games_left <= 0 and lots_left <= 0:
		return "THE HOUSE IS DONE WITH YOU TONIGHT. LEAVE."
	if r.cash < 1:
		return "NO COINS. THE TABLE WILL NOT TAKE PROMISES."
	return "STAKE UP TO %d. EVERY GAME FAVOURS THE HOUSE. YOU KNOW THIS." % stake_max(r)
