class_name UiAltar
extends TsScreen
## The Altar, reached from the title: a dark stone slab between two candles, an ectoplasm counter, and one card per
## upgrade (game/data/upgrades.json) with its rank pips and cost. Buying spends ectoplasm: a green wisp flies from the
## counter to the card, a pip lights with a ring, the counter counts down. A card you cannot afford shudders red.
## Ectoplasm is earned only, never sold. Everything the logic provides (Upgrades.buy, profile fields) is reached through
## guards, so the screen also runs from injected data (sheets and tests set `ecto`, `ranks` and `buy_fn`).
##   var a := UiAltar.new(); a.store = relic_store; add_child(a); a.closed.connect(...)

signal closed
signal bought(id: String)

const WISP_SECS: float = 0.85

const UPGRADES_PATH: String = "res://game/data/upgrades.json"
const COLS: int = 4
const CARD_W: float = 142.0
const CARD_H: float = 88.0
const CARD_GAP: float = 8.0
const GRID_X: float = 24.0
const GRID_Y: float = 108.0
const BACK_RECT := Rect2(270.0, 322.0, 100.0, 20.0)
const BUY_SECS: float = 1.1
const SHUDDER_SECS: float = 0.45
const FALLBACK_DEFS: Array = [
	{"id": "shelf", "name": "Extra Shelf", "text": "One more shelf slot in the shop.", "cost": 4, "max_rank": 3},
	{"id": "spell_slot", "name": "Known Page", "text": "Start every run knowing one spell of your choice.", "cost": 6, "max_rank": 2},
	{"id": "casts", "name": "Deeper Well", "text": "One more cast each night.", "cost": 8, "max_rank": 3},
	{"id": "tells", "name": "Open Eyes", "text": "Tells show more often.", "cost": 5, "max_rank": 3},
	{"id": "rent", "name": "Kind Landlord", "text": "The first rent is lower.", "cost": 5, "max_rank": 2},
	{"id": "pendulum", "name": "The Pendulum", "text": "A sixth tool: is it cursed, yes or no.", "cost": 12, "max_rank": 1},
	{"id": "keep_cash", "name": "Salvage", "text": "After a loss, start the next run with a tenth of the cash.", "cost": 7, "max_rank": 2},
	{"id": "candle", "name": "Altar Candle", "text": "Start every run with less Dread.", "cost": 6, "max_rank": 3},
]

static var force_defs: Array = []  ## sheets and tests: replace the data file

var store: Object  ## the profile (RelicStore): ectoplasm and upgrade ranks are read from it when it has them
var ecto: int = 0
var ranks: Dictionary = {}  ## upgrade id -> rank bought
var buy_fn: Callable = Callable()  ## tests: (id) -> "ok" or a reason; default is Upgrades.buy(id, store)
var last_msg: String = ""

var _shown_ecto: float = -1.0
var _fx: Array[Dictionary] = []  ## {kind, id, age}
var _shudder: Dictionary = {}  ## id -> age
var _wisps: Array[Dictionary] = []  ## {from, to, age, delay}
var _icons: Dictionary = {}
var _intro_t: float = 0.0


# ---------------------------------------------------------------- data (pure, unit-tested)

## The upgrade definitions: forced, else game/data/upgrades.json (an array, or {upgrades: [...]}). Empty without them.
static func defs() -> Array[Dictionary]:
	var raw: Variant = force_defs if not force_defs.is_empty() else UiOccult.read_json(UPGRADES_PATH)
	if raw is Dictionary and (raw as Dictionary).has("upgrades"):
		raw = (raw as Dictionary)["upgrades"]
	var out: Array[Dictionary] = []
	if raw is Array:
		for d: Variant in raw:
			if d is Dictionary and str((d as Dictionary).get("id", "")) != "":
				out.append(d as Dictionary)
	return out


## True when the logic can sell upgrades (the script exists with buy) and there is data: the title offers the Altar.
static func available() -> bool:
	return not defs().is_empty()


static func max_rank(def: Dictionary) -> int:
	return maxi(int(def.get("max_rank", 1)), 1)


## The ectoplasm the next rank costs, as Upgrades.cost_of: the listed cost times the rank being bought (a list gives
## one entry per rank instead).
static func cost_of(def: Dictionary, rank: int) -> int:
	var c: Variant = def.get("cost", 0)
	if c is Array and not (c as Array).is_empty():
		return int((c as Array)[clampi(rank, 0, (c as Array).size() - 1)])
	return int(c) * (rank + 1)


## "maxed", "buy" (affordable) or "dear" for one card.
static func card_state(def: Dictionary, rank: int, have: int) -> String:
	if rank >= max_rank(def):
		return "maxed"
	return "buy" if have >= cost_of(def, rank) else "dear"


## The profile's ectoplasm (0 without the field).
static func store_ecto(st: Object) -> int:
	for f: String in ["ectoplasm", "ecto"]:
		if st != null and f in st:
			return int(st.get(f))
	return 0


## The profile's ranks as id -> int ({} without the field).
static func store_ranks(st: Object) -> Dictionary:
	for f: String in ["upgrade_ranks", "upgrades", "ranks"]:
		if st != null and f in st and st.get(f) is Dictionary:
			var out: Dictionary = {}
			for k: Variant in (st.get(f) as Dictionary).keys():
				out[str(k)] = int((st.get(f) as Dictionary)[k])
			return out
	return {}


## Whether a buy result means it worked: true, "ok", or a dictionary with ok.
static func buy_ok(result: Variant) -> bool:
	if result is bool:
		return result as bool
	if result is Dictionary:
		return bool((result as Dictionary).get("ok", false))
	return str(result) == "ok"


static func buy_reason(result: Variant) -> String:
	if result is Dictionary:
		return str((result as Dictionary).get("why", (result as Dictionary).get("reason", "NOT NOW")))
	return str(result)


## The card rectangle for slot i.
static func card_rect(i: int) -> Rect2:
	return Rect2(GRID_X + float(i % COLS) * (CARD_W + CARD_GAP), GRID_Y + float(i / COLS) * (CARD_H + CARD_GAP), CARD_W, CARD_H)


# ---------------------------------------------------------------- life

func ts_ready() -> void:
	_pull()
	_shown_ecto = float(ecto)
	var ids: Array[String] = ts_menu_ids()
	focus_id = ids[0] if not ids.is_empty() else "back"


func _pull() -> void:
	if store != null:
		ecto = store_ecto(store)
		ranks = store_ranks(store)


func ts_menu_ids() -> Array[String]:
	var ids: Array[String] = []
	for d: Dictionary in defs():
		ids.append("up:%s" % str(d["id"]))
	ids.append("back")
	return ids


func ts_activate_menu(id: String) -> void:
	if id == "back":
		closed.emit()
	elif id.begins_with("up:"):
		try_buy(id.trim_prefix("up:"))


func ts_escape_menu() -> void:
	closed.emit()


func ts_key(k: int) -> bool:
	var ids: Array[String] = ts_menu_ids()
	var at: int = ids.find(focus_id)
	var n: int = defs().size()
	match k:
		KEY_LEFT:
			ts_move_focus(-1)
			return true
		KEY_RIGHT:
			ts_move_focus(1)
			return true
		KEY_UP:
			focus_id = ids[at - COLS] if at >= COLS and at < n else (ids[maxi(n - 1, 0)] if at == n else focus_id)
			return true
		KEY_DOWN:
			focus_id = ids[at + COLS] if at >= 0 and at + COLS < n else ("back" if at >= 0 and at < n else focus_id)
			return true
	return super.ts_key(k)


## Tries to buy one rank. Returns "ok" or the reason it did not happen (the card shudders on a no).
func try_buy(id: String) -> String:
	var def: Dictionary = {}
	for d: Dictionary in defs():
		if str(d["id"]) == id:
			def = d
	if def.is_empty():
		return "unknown"
	var rank: int = int(ranks.get(id, 0))
	var state: String = card_state(def, rank, ecto)
	if state != "buy":
		_shudder[id] = 0.0
		last_msg = "ALREADY AT ITS FULL POWER." if state == "maxed" else "NOT ENOUGH ECTOPLASM."
		if sfx != null:
			sfx.ui("hover")
		return state
	var cost: int = cost_of(def, rank)
	var result: Variant = _call_buy(id)
	if not buy_ok(result):
		_shudder[id] = 0.0
		last_msg = UiEngage.ascii_up(buy_reason(result))
		return buy_reason(result)
	if store != null and (store_ecto(store) != ecto or store_ranks(store).get(id, 0) != rank):
		_pull()  # the logic keeps the books
	else:
		ecto -= cost  # injected data: keep our own
		ranks[id] = rank + 1
	_fx.append({"kind": "buy", "id": id, "age": 0.0})
	_spawn_wisps(ts_menu_ids().find("up:%s" % id), cost)
	last_msg = "%s RANK %d." % [UiEngage.ascii_up(str(def.get("name", id))), rank + 1]
	if sfx != null:
		sfx.ui("altar_buy")
	bought.emit(id)
	return "ok"


func _call_buy(id: String) -> Variant:
	if buy_fn.is_valid():
		return buy_fn.call(id)
	if store is RelicStore:
		return Upgrades.buy(id, store as RelicStore)
	return "NO PROFILE"


func _spawn_wisps(slot: int, cost: int) -> void:
	if slot < 0:
		return
	var to: Vector2 = card_rect(slot).position + Vector2(CARD_W * 0.5, 14.0)
	for k: int in range(clampi(cost, 3, 10)):
		_wisps.append({"from": COUNTER_AT + Vector2(0.0, 4.0), "to": to, "age": 0.0, "delay": float(k) * 0.07, "k": k})


func _process(delta: float) -> void:
	super._process(delta)
	_intro_t += delta
	if _shown_ecto >= 0.0:
		_shown_ecto = UiMotion.ui_approach(_shown_ecto, float(ecto), delta, 7.0)
		if absf(_shown_ecto - float(ecto)) < 0.05:
			_shown_ecto = float(ecto)
	for f: Dictionary in _fx:
		f["age"] = float(f["age"]) + delta
	while not _fx.is_empty() and float(_fx[0]["age"]) > BUY_SECS:
		_fx.pop_front()
	for id: Variant in _shudder.keys():
		_shudder[id] = float(_shudder[id]) + delta
		if float(_shudder[id]) > SHUDDER_SECS:
			_shudder.erase(id)
	for w: Dictionary in _wisps:
		w["age"] = float(w["age"]) + delta
	while not _wisps.is_empty() and float(_wisps[0]["age"]) - float(_wisps[0]["delay"]) > WISP_SECS:
		_wisps.pop_front()


func _fx_age(id: String) -> float:
	for f: Dictionary in _fx:
		if str(f["id"]) == id:
			return float(f["age"])
	return 9.0


# ---------------------------------------------------------------- drawing

const COUNTER_AT := Vector2(548.0, 40.0)


func ts_draw_scene(c: TsCanvas) -> void:
	c.fill(Rect2(Vector2.ZERO, ShopGame.VIEW), 0)
	var flick: bool = UiMotion.ui_hash(int(c.t * 9.0), 31) < 0.5
	UiFrames.ui_glow(c, Vector2(320.0, 64.0), 150 if flick else 156, 8, 9, 0.42)
	_draw_slab(c)
	for side: int in range(2):
		var cx: float = 118.0 if side == 0 else 522.0
		UiFrames.ui_glow(c, Vector2(cx, 44.0), 54 if flick else 58, 9, 10, 0.8)
		UiFrames.ui_candle(c, cx, 86.0, 8, 26 + side * 4, c.t + float(side) * 1.7, 0, false, 5 + side, 2)
	var fade: float = UiMotion.ui_out(_intro_t / 0.6)
	if fade > 0.0:
		c.head_c(320.0, 16.0, "THE ALTAR", 11 if fade > 0.7 else 9, 2)
		c.text_c(320.0, 46.0, "ECTOPLASM IS EARNED, NEVER SOLD. SPEND IT WELL.", 14 if fade > 0.9 else 4)
	_draw_counter(c)


## The stone slab the candles stand on: a wide dark block with a bevel and a faint rune row.
func _draw_slab(c: TsCanvas) -> void:
	var slab := Rect2(96.0, 86.0, 448.0, 12.0)
	c.fill(slab, 1)
	c.fill(Rect2(slab.position.x, slab.position.y, slab.size.x, 1.0), 4)
	c.fill(Rect2(slab.position.x, slab.position.y + 1.0, slab.size.x, 1.0), 3)
	c.fill(Rect2(slab.position.x, slab.end.y - 2.0, slab.size.x, 2.0), 0)
	for i: int in range(28):  # worn runes along the front
		var rx: float = slab.position.x + 12.0 + float(i) * 15.5
		var rh: int = 2 + int(UiMotion.ui_hash(i, 4, 77) * 4.0)
		c.fill(Rect2(rx, slab.position.y + 4.0, 1.0, float(rh)), 2)
		if UiMotion.ui_hash(i, 5, 77) < 0.5:
			c.fill(Rect2(rx + 1.0, slab.position.y + 5.0, 2.0, 1.0), 2)


## The ectoplasm counter: a green wisp glyph and the count, which ticks down as a buy lands.
func _draw_counter(c: TsCanvas) -> void:
	var at: Vector2 = COUNTER_AT
	var shown: int = int(round(_shown_ecto)) if _shown_ecto >= 0.0 else ecto
	var counting: bool = shown != ecto
	c.frame(Rect2(at.x - 40.0, at.y - 22.0, 92.0, 38.0), "panel")
	_draw_wisp(c, Vector2(at.x - 26.0, at.y - 6.0), c.t, 1.0)
	c.text(Vector2(at.x - 8.0, at.y - 16.0), "ECTOPLASM", 7, 1)
	c.head_c(at.x + 14.0, at.y - 4.0, "%d" % shown, 7 if not counting else 15, 1)
	for w: Dictionary in _wisps:
		var u: float = (float(w["age"]) - float(w["delay"])) / WISP_SECS
		if u <= 0.0 or u >= 1.0:
			continue
		var e: float = UiMotion.ui_in_out(u)
		var p: Vector2 = (w["from"] as Vector2).lerp(w["to"] as Vector2, e)
		p.y -= sin(e * PI) * 26.0 * (1.0 if int(w["k"]) % 2 == 0 else -0.5)
		for tr: int in range(1, 4):  # a fading trail of embers behind the wisp
			var eb: float = UiMotion.ui_in_out(maxf(u - 0.05 * float(tr), 0.0))
			var tp: Vector2 = (w["from"] as Vector2).lerp(w["to"] as Vector2, eb)
			tp.y -= sin(eb * PI) * 26.0 * (1.0 if int(w["k"]) % 2 == 0 else -0.5)
			c.fill(Rect2(tp.x + 5.0, tp.y + 8.0, 3.0 - float(tr) * 0.6, 3.0 - float(tr) * 0.6), 6 if tr < 3 else 5)
		_draw_wisp(c, p, c.t + float(w["k"]) * 0.3, 2.0)


## A tiny ectoplasm wisp: a green teardrop with a bright core. scale 1 is 7x9.
func _draw_wisp(c: TsCanvas, at: Vector2, t: float, s: float) -> void:
	if s > 1.0:  # the flying wisp: the same teardrop at 2x, so it reads at 1x scale of the window
		c.draw_set_transform(at, 0.0, Vector2(s, s))
		_draw_wisp(c, Vector2.ZERO, t, 1.0)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var sway: float = floorf(sin(t * 3.0) * 1.0 + 0.5)
	if s >= 1.0:
		c.fill(Rect2(at.x + 3.0 + sway, at.y, 1.0, 2.0), 5)
		c.fill(Rect2(at.x + 2.0, at.y + 2.0, 3.0, 2.0), 6)
		c.fill(Rect2(at.x + 1.0, at.y + 4.0, 5.0, 3.0), 6)
		c.fill(Rect2(at.x + 2.0, at.y + 7.0, 3.0, 1.0), 5)
		c.fill(Rect2(at.x + 3.0, at.y + 4.0, 1.0, 2.0), 15)
		c.fill(Rect2(at.x + 2.0, at.y + 5.0, 1.0, 1.0), 7)
	else:
		c.fill(Rect2(at.x, at.y, 3.0, 3.0), 6)
		c.fill(Rect2(at.x + 1.0, at.y + 1.0, 1.0, 1.0), 15)


func ts_draw_menu(c: TsCanvas) -> void:
	var list: Array[Dictionary] = defs()
	if list.is_empty():
		c.text_c(320.0, 190.0, "THE ALTAR IS BARE. NOTHING TO BUY YET.", 14)
	for i: int in range(list.size()):
		_draw_card(c, i, list[i])
	c.button("back", BACK_RECT, "BACK [ESC]", true, false)
	if focus_id == "back":
		c.cursor_flame(Vector2(BACK_RECT.position.x - 14.0, BACK_RECT.position.y + 6.0))
	var note: String = last_msg
	if note != "":
		c.text_c(320.0, 306.0, note, 11 if note.contains("RANK") else 13, 1)
	elif _intro_t > 1.0:
		c.text_c(320.0, 306.0, "ARROWS, ENTER TO BUY. THE DEAD DO NOT GIVE REFUNDS.", 4)


func _draw_card(c: TsCanvas, i: int, def: Dictionary) -> void:
	var id: String = str(def["id"])
	var wid: String = "up:%s" % id
	var rank: int = int(ranks.get(id, 0))
	var mx: int = max_rank(def)
	var state: String = card_state(def, rank, ecto)
	var u: float = UiMotion.ui_back((_intro_t - 0.09 * float(i) - 0.2) / 0.4)
	if u <= 0.0:
		c.add(wid, card_rect(i), false)
		return
	var rect: Rect2 = card_rect(i)
	rect.position.y += floorf((1.0 - minf(u, 1.0)) * 14.0)
	if _shudder.has(id):
		rect.position.x += UiOccult.shudder(float(_shudder[id]) / SHUDDER_SECS)
	c.add(wid, rect, true)
	var focused: bool = is_focused(wid)
	var buy_age: float = _fx_age(id)
	var kind: String = "note"
	if _shudder.has(id) and state == "dear":
		kind = "red"
	elif state == "maxed":
		kind = "btn_off"
	elif focused or buy_age < 0.5:
		kind = "gold"
	c.frame(rect, kind)
	var dim: bool = state != "buy" and state != "maxed"
	var ink: int = 4 if state == "maxed" else 0
	# icon in a small well, name beside it
	var well := Rect2(rect.position.x + 6.0, rect.position.y + 6.0, 20.0, 20.0)
	c.fill(well, 1)
	c.fill(Rect2(well.position.x, well.end.y - 1.0, well.size.x, 1.0), 8)
	c.draw_texture(_icon(id), well.position + Vector2(2.0, 2.0), Color(1, 1, 1, 0.45 if dim else 1.0))
	var name_lines: PackedStringArray = UiPixelFont.ui_wrap(UiEngage.ascii_up(str(def.get("name", id))), int(rect.size.x) - 40)
	for j: int in range(mini(name_lines.size(), 2)):
		c.text(Vector2(well.end.x + 6.0, rect.position.y + 8.0 + float(j * UiPixelFont.LINE_H)), name_lines[j], 12 if state != "maxed" else 8, 1, false)
	c.fill(Rect2(rect.position.x + 6.0, rect.position.y + 29.0, rect.size.x - 12.0, 1.0), 10 if not dim else 9)
	var body: PackedStringArray = UiPixelFont.ui_wrap(UiEngage.ascii_up(str(def.get("text", ""))), int(rect.size.x) - 14)
	for j: int in range(mini(body.size(), 3)):
		var ln: String = body[j]
		if j == 2 and body.size() > 3:
			ln = ln.substr(0, maxi(ln.length() - 2, 1)) + ".."
		c.text(Vector2(rect.position.x + 7.0, rect.position.y + 34.0 + float(j * UiPixelFont.LINE_H)), ln, ink, 1, false)
	# rank pips
	var py: float = rect.end.y - 17.0
	for p: int in range(mx):
		var px: float = rect.position.x + 8.0 + float(p) * 9.0
		var lit: bool = p < rank
		var fresh: bool = lit and p == rank - 1 and buy_age < 0.6
		c.fill(Rect2(px, py, 7.0, 7.0), 0)
		c.fill(Rect2(px + 1.0, py + 1.0, 5.0, 5.0), 7 if lit else 2)
		if lit:
			c.fill(Rect2(px + 1.0, py + 1.0, 2.0, 2.0), 15)
		if fresh:
			var ring: float = UiMotion.ui_out(buy_age / 0.6) * 9.0
			c.draw_rect(Rect2(px - ring + 3.0, py - ring + 3.0, ring * 2.0 + 1.0, ring * 2.0 + 1.0), c.c(15 if buy_age < 0.25 else 7), false, 1.0)
			var grow: float = 3.0 * maxf(0.0, 1.0 - buy_age / 0.4)  # the pip swells as it catches
			if grow > 0.0:
				c.fill(Rect2(px - grow, py - grow, 7.0 + grow * 2.0, 7.0 + grow * 2.0), 15 if buy_age < 0.2 else 7)
				c.fill(Rect2(px + 1.0, py + 1.0, 5.0, 5.0), 15 if buy_age < 0.2 else 6)
			UiFrames.ui_flame(c, Vector2(px + 1.0, py - 9.0), c.t, 0, false, 3)  # a flame lifts off it
	if state == "maxed":
		c.text(Vector2(rect.end.x - 40.0, py), "MAXED", 7, 1, false)
	else:
		var cost: int = cost_of(def, rank)
		var col: int = 7 if state == "buy" else 13
		var s: String = "%d" % cost
		c.text(Vector2(rect.end.x - float(UiPixelFont.ui_width(s)) - 8.0, py), s, col, 1, false)
		_draw_wisp(c, Vector2(rect.end.x - float(UiPixelFont.ui_width(s)) - 20.0, py - 1.0), c.t, 1.0)
	if buy_age < 0.45:  # the flash of a buy: the whole card whites out, then a green wash, then a ring that spreads
		if buy_age < 0.09:
			c.draw_rect(rect, Color(c.c(15), 0.85))
		elif buy_age < 0.3:
			c.draw_rect(rect, Color(c.c(7), 0.45 * (1.0 - (buy_age - 0.09) / 0.21)))
		c.draw_rect(rect.grow(2.0 + buy_age * 20.0), c.c(7 if buy_age > 0.12 else 15), false, 2.0)
	if focused and not dim:
		c.fill(Rect2(rect.position.x + 2.0, rect.end.y - 3.0, rect.size.x - 4.0, 1.0), 11 if fmod(c.t, 1.0) < 0.7 else 10)


## The 16x16 icon: SpriteKit.upgrade_icon(id) when the art worker has shipped it, else a rune from the id.
func _icon(id: String) -> ImageTexture:
	if _icons.has(id):
		return _icons[id] as ImageTexture
	var tex: ImageTexture = null
	var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
	if sk != null and UiOccult.static_has(sk, "upgrade_icon"):
		tex = sk.call("upgrade_icon", id) as ImageTexture
	if tex == null:
		tex = placeholder_icon(id)
	_icons[id] = tex
	return tex


## A 16x16 stand-in rune: a diamond with arms and a notch, shaped by the id.
static func placeholder_icon(id: String) -> ImageTexture:
	var pal: PackedColorArray = RoomPalette.colors()
	var img: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var h: int = id.hash() & 0x7FFFFFFF
	for y: int in range(16):
		for x: int in range(16):
			var d: int = absi(x - 8) + absi(y - 8)
			if d == 7:
				img.set_pixel(x, y, pal[7])
			elif d < 7 and d > 4 and (x + y + h) % 3 == 0:
				img.set_pixel(x, y, pal[6])
	for k: int in range(2, 14):
		if (h >> (k % 8)) & 1 == 1:
			img.set_pixel(8, k, pal[15])
		else:
			img.set_pixel(k, 8, pal[15])
	img.set_pixel(8, 8, pal[11])
	return ImageTexture.create_from_image(img)
