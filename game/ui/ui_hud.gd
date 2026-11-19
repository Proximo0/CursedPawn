class_name UiHud
extends Control
## Draws the whole shop screen at 640x360 (inside a SubViewport) from a ShopGame's state, and keeps the clickable
## widget list the draw pass built so the game can hit-test mouse positions. Palette indices (RoomPalette):
## 0 black, 1-4 purples, 5-7 greens, 8 dark wood, 9 wood, 10 amber, 11 candle yellow, 12 dark red, 13 red,
## 14 bone grey, 15 bone white. Small accents: ink-written log lines, floating cash numbers with a coin flip, a Dread
## candle that burns down, gutters and drips, brass buttons that squish, flames that flicker.
## Layout constants assume the room's counter front is at COUNTER_FRONT_Y; tool buttons, the tarot deck and the shelf
## item rectangles (ShopGame.shelf_rects) sit over the matching room props.

const TOP_H: float = 18.0
const COUNTER_FRONT_Y: float = 227.0
const TOOL_X0: float = 204.0
const TOOL_Y: float = 190.0
const TOOL_SIZE: float = 30.0
const TOOL_STEP: float = 36.0
const DECK_RECT := Rect2(400.0, 171.0, 32.0, 53.0)
const OFFER_RECT := Rect2(77.0, 271.0, 420.0, 31.0)
const OFFER_Y: float = 276.0
const OFFER_H: float = 21.0
const LOG_RECT := Rect2(5.0, 310.0, 440.0, 46.0)
const LOG_LINES: int = 4
const LOG_CPS: float = 70.0  ## ink writing speed, characters per second
const STAKE_RECT := Rect2(185.0, 120.0, 270.0, 68.0)
const END_RECT := Rect2(96.0, 22.0, 448.0, 316.0)
const DREAD_RECT := Rect2(592.0, 21.0, 42.0, 68.0)
const CANDLE_BASE_Y: float = 81.0
const CANDLE_MAX_H: int = 38
const CANDLE_MIN_H: int = 3
const POP_SECS: float = 0.95
const COIN_FLIP_SECS: float = 0.45
const NOTE_LINES: int = 3

var game: ShopGame
var widgets: Array[Dictionary] = []  ## {id, rect, enabled} in draw order; the last containing a point wins
var _t: float = 0.0
var _pal: PackedColorArray = RoomPalette.colors()
var _tool_tex: Dictionary = {}
var _deck_tex: ImageTexture
var _hov_prev: String = ""
var _hov_age: float = 0.0
var _down_prev: String = ""
var _down_age: float = 0.0
var _run_id: int = 0
var _cash_prev: int = 0
var _pops: Array[Dictionary] = []  ## floating cash numbers {text, age, col}
var _coin_t: float = 9.0
var _drips: Array[Dictionary] = []  ## wax drops falling off the Dread candle {x, y, vy}
var _drip_wait: float = 1.0
var _stake_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var spell_bar := UiSpellBar.new()  ## the occult round: spells on keys 5-0, the Midnight Table, found popups
var table := UiTable.new()
var found := UiFound.new()


func _init() -> void:
	name = "UiHud"
	size = ShopGame.VIEW
	custom_minimum_size = ShopGame.VIEW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 20261118


## Run events for the occult widgets (spell flashes, table animations, found popups). Called by ShopGame.
func feed(events: Array[Dictionary]) -> void:
	spell_bar.feed(events)
	table.feed(events)
	found.feed(events)


## The topmost enabled-or-not widget id under p (UI grid coordinates), "" for none.
func widget_at(p: Vector2) -> String:
	for i: int in range(widgets.size() - 1, -1, -1):
		if (widgets[i]["rect"] as Rect2).has_point(p):
			return str(widgets[i]["id"]) if bool(widgets[i]["enabled"]) else ""
	return ""


## Starts a floating +N / -N number by the cash readout and flips the coin.
func ui_pop(amount: int) -> void:
	if amount == 0:
		return
	_pops.append({"text": "%+d" % amount, "age": 0.0, "col": 7 if amount > 0 else 13})
	_coin_t = 0.0


## 0..1 how close the Dread is to waking the shop.
func ui_dread_frac(r: RunState) -> float:
	return clampf(r.dread / maxf(r.tuning.wake_threshold, 0.1), 0.0, 1.0)


## Height of the Dread candle's wax for a dread fraction: full at 0, a stub at 1.
static func ui_candle_height(frac: float) -> int:
	return CANDLE_MIN_H + int(round(float(CANDLE_MAX_H - CANDLE_MIN_H) * (1.0 - clampf(frac, 0.0, 1.0))))


## The flame the candle shows: 0 calm, 1 shrinking, 2 guttering, -1 snuffed.
static func ui_flame_size(frac: float) -> int:
	if frac >= 1.0:
		return -1
	return 0 if frac < 0.5 else (1 if frac < 0.75 else 2)


func _process(delta: float) -> void:
	_t += delta
	if game == null or game.run == null:
		return
	_hov_age = 0.0 if game.hover_id != _hov_prev else _hov_age + delta
	_hov_prev = game.hover_id
	_down_age = 0.0 if game.down_id != _down_prev else _down_age + delta
	_down_prev = game.down_id
	var r: RunState = game.view_run()
	if r.get_instance_id() != _run_id:
		_run_id = r.get_instance_id()
		_cash_prev = r.cash
		_pops.clear()
	elif r.cash != _cash_prev:
		ui_pop(r.cash - _cash_prev)
		_cash_prev = r.cash
	_coin_t += delta
	for p: Dictionary in _pops:
		p["age"] = float(p["age"]) + delta
	while not _pops.is_empty() and float(_pops[0]["age"]) > POP_SECS:
		_pops.pop_front()
	_stake_t = UiMotion.ui_approach(_stake_t, 1.0 if game.stake_open else 0.0, delta, 14.0)
	spell_bar.tick(delta)
	table.tick(delta, r)
	found.tick(delta)
	_ui_drips(r, delta)


func _ui_drips(r: RunState, delta: float) -> void:
	var frac: float = ui_dread_frac(r)
	var cx: float = DREAD_RECT.position.x + DREAD_RECT.size.x * 0.5
	_drip_wait -= delta
	if _drip_wait <= 0.0 and frac < 1.0:
		_drip_wait = lerpf(3.2, 0.7, frac) * (0.7 + _rng.randf() * 0.6)
		var top: float = CANDLE_BASE_Y - float(ui_candle_height(frac))
		_drips.append({"x": cx - 3.0 if _rng.randf() < 0.5 else cx + 2.0, "y": top + 2.0, "vy": 0.0})
	for d: Dictionary in _drips:
		d["vy"] = float(d["vy"]) + 90.0 * delta
		d["y"] = float(d["y"]) + float(d["vy"]) * delta
	var i: int = _drips.size() - 1
	while i >= 0:
		if float(_drips[i]["y"]) >= CANDLE_BASE_Y - 2.0:
			_drips.remove_at(i)
		i -= 1


func _c(i: int) -> Color:
	return _pal[i]


# ---------------------------------------------------------------- drawing helpers

func _text(pos: Vector2, s: String, col: int, scale: int = 1, shadow: bool = true) -> void:
	UiPixelFont.ui_draw(self, pos, s, _c(col), scale, shadow, _c(0))


func _text_c(cx: float, y: float, s: String, col: int, scale: int = 1, shadow: bool = true) -> void:
	_text(Vector2(cx - float(UiPixelFont.ui_width(s, scale)) * 0.5, y), s, col, scale, shadow)


func _frame(rect: Rect2, kind: String) -> void:
	UiFrames.ui_draw(self, rect, kind)


func _rect(rect: Rect2, col: int) -> void:
	draw_rect(rect, _c(col))


## A coin; flip 0..1 turns it edge-on and back (the cash change accent). flip < 0 draws it still.
func _coin(c: Vector2, flip: float = -1.0) -> void:
	var hw: int = 2 if flip < 0.0 or flip > 1.0 else int(round(absf(cos(flip * TAU)) * 2.0))
	_rect(Rect2(c.x - float(hw) - 1.0, c.y - 3.0, float(2 * hw + 3), 7.0), 0)
	_rect(Rect2(c.x - float(hw), c.y - 2.0, float(2 * hw + 1), 5.0), 10)
	if hw > 0:
		_rect(Rect2(c.x - float(hw), c.y - 2.0, 1.0, 5.0), 11)
		_rect(Rect2(c.x + float(hw), c.y - 1.0, 1.0, 4.0), 9)
	else:
		_rect(Rect2(c.x, c.y - 2.0, 1.0, 5.0), 9)


func _add(id: String, rect: Rect2, enabled: bool = true) -> void:
	widgets.append({"id": id, "rect": rect, "enabled": enabled})


## A brass button; hover flicker and the pressed squish come from the game's pointer state.
func _button(id: String, rect: Rect2, label: String, enabled: bool = true, gold: bool = false) -> void:
	_add(id, rect, enabled)
	UiFrames.ui_button(self, rect, label, enabled, gold, game.hover_id == id, game.down_id == id, _hov_age, _down_age)


func _tool_icon(tool: String) -> ImageTexture:
	if not _tool_tex.has(tool):
		_tool_tex[tool] = SpriteKit.tool_texture(tool)
	return _tool_tex[tool] as ImageTexture


# ---------------------------------------------------------------- main draw

func _draw() -> void:
	if game == null or game.run == null:
		return
	widgets.clear()
	var r: RunState = game.view_run()
	_draw_top(r)
	if UiOccult.in_table(r) and not game.end_panel_visible():
		table.draw(self, r, spell_bar, game.hover_id)
		_draw_dread(r)
		_draw_log()
		_draw_pops()
		found.draw(self)
		if found.active():
			widgets.clear()
		if not game.cards.is_empty():
			widgets.clear()
			_draw_card(game.cards[0])
		return
	_draw_dread(r)
	if game != null and game.hints != null:
		TsHintFrame.ts_draw(self, game.hints.text(), game.hints.age)
	if game.end_panel_visible():
		_draw_log()
		widgets.clear()
		_draw_end(r)
		_draw_pops()
		return
	if not r.customer.is_empty():
		if str(r.customer["kind"]) == RunState.SELLER:
			_draw_seller(r)
		else:
			_draw_buyer(r)
	else:
		_text(Vector2(80.0, 240.0), "THE SHOP IS QUIET...", 14)
	_draw_log()
	_draw_side_buttons(r)
	if not game.is_replaying():
		spell_bar.draw(self, r, game.hover_id)
	if (game.stake_open or _stake_t > 0.02) and not game.is_replaying():
		_draw_stake(r)
	if spell_bar.pending_item_spell != "":
		widgets.clear()
		spell_bar.draw_chips(self, r, Rect2(60.0, 112.0, 440.0, 78.0), game.hover_id, "%s: PICK A HELD ITEM" % spell_bar.pending_item_spell.to_upper())
		_button("pick_cancel", Rect2(430.0, 116.0, 64.0, 15.0), "CANCEL", true)
	if game.is_replaying():
		_draw_replay_banner()
	_draw_pops()
	found.draw(self)
	if found.active():
		widgets.clear()
	if not game.cards.is_empty():
		widgets.clear()
		_draw_card(game.cards[0])


func _draw_top(r: RunState) -> void:
	_frame(Rect2(0.0, 0.0, ShopGame.VIEW.x, TOP_H), "panel")
	_text(Vector2(10.0, 5.0), "NIGHT %d/%d" % [r.night, int(r.tuning.nights)], 15)
	_text(Vector2(112.0, 5.0), ShopGame.ui_clock_text(r.clock), 14)
	_coin(Vector2(212.0, 9.0), _coin_t / COIN_FLIP_SECS)
	_text(Vector2(221.0, 5.0), "%d" % r.cash, 11)
	_text(Vector2(278.0, 5.0), "RENT %d" % r.rent_for(r.night), 15 if r.cash >= r.rent_for(r.night) else 13)


func _draw_pops() -> void:
	for p: Dictionary in _pops:
		var u: float = float(p["age"]) / POP_SECS
		var col: int = int(p["col"])
		if u > 0.7:
			col = 4 if col == 7 else 12
		var y: float = 22.0 - UiMotion.ui_out(u) * 14.0
		_text(Vector2(221.0, floorf(y)), str(p["text"]), col, 1, true)


## The Dread meter: a candle on a plaque. The wax burns down as Dread rises, the flame shrinks and gutters, drips run
## down the wax, and at the wake threshold it goes out in a curl of smoke.
func _draw_dread(r: RunState) -> void:
	var frac: float = ui_dread_frac(r)
	_frame(DREAD_RECT, "panel")
	var cx: float = DREAD_RECT.position.x + DREAD_RECT.size.x * 0.5
	_text_c(cx, DREAD_RECT.position.y + 4.0, "DREAD", 14 if frac < 0.75 else 13, 1, true)
	var h: int = ui_candle_height(frac)
	var fs: int = ui_flame_size(frac)
	if fs == 2 and UiMotion.ui_hash(int(_t * 14.0), 4) < 0.35:
		fs = -2  # the flame gutters out for a beat
	var top: float = UiFrames.ui_candle(self, cx, CANDLE_BASE_Y, 8, h, _t, fs, frac >= 0.75, 2)
	for f: float in [0.25, 0.5, 0.75]:
		var ty: float = CANDLE_BASE_Y - float(ui_candle_height(f))
		_rect(Rect2(cx + 7.0, ty, 3.0, 1.0), 9 if frac < f else 13)
	for d: Dictionary in _drips:
		_rect(Rect2(floorf(float(d["x"])), floorf(float(d["y"])), 1.0, 2.0), 15)


func _draw_log() -> void:
	_frame(LOG_RECT, "ledger")
	var vis: Array[Dictionary] = []
	var wrap_w: int = int(LOG_RECT.size.x) - UiFrames.LEDGER_TEXT_X - 8
	for ei: int in range(game.log_lines.size()):
		var off: int = 0
		for ln: String in UiPixelFont.ui_wrap(game.log_lines[ei], wrap_w):
			vis.append({"t": ln, "e": ei, "o": off})
			off += ln.length() + 1
	var first: int = maxi(vis.size() - LOG_LINES, 0)
	var newest: int = game.log_lines.size() - 1
	var age: float = game.log_age[newest] if newest >= 0 and newest < game.log_age.size() else 9.0
	for i: int in range(first, vis.size()):
		var row: Dictionary = vis[i]
		var ln: String = str(row["t"])
		var pos := Vector2(LOG_RECT.position.x + float(UiFrames.LEDGER_TEXT_X), LOG_RECT.position.y + 5.0 + float(i - first) * float(UiPixelFont.LINE_H))
		if int(row["e"]) != newest:
			_text(pos, ln, 8, 1, false)
			continue
		var shown: int = int(age * LOG_CPS) - int(row["o"])
		var n: int = clampi(shown, 0, ln.length())
		if age < 1.0 and n > 0:
			_rect(Rect2(pos.x - 2.0, pos.y - 1.0, float(UiPixelFont.ui_width(ln.substr(0, n))) + 4.0, 9.0), 11 if age < 0.4 else 15)
		UiPixelFont.ui_draw_ink(self, pos, ln, _c(0), _c(12), n, shown >= 0 and shown < ln.length(), _c(0), _t)


func _draw_side_buttons(r: RunState) -> void:
	var can_replay: bool = game.rec != null and not game.rec.wake_at.is_empty() and not game.is_replaying()
	_button("replay", Rect2(452.0, 312.0, 86.0, 17.0), "REPLAY [R]", can_replay)
	_button("relics", Rect2(544.0, 312.0, 86.0, 17.0), "RELIQUARY")
	_text(Vector2(456.0, 338.0), "HELD %d" % r.inventory.size(), 14)
	_text(Vector2(548.0, 338.0), "SEED %d" % game.seed_now, 3)


func _draw_replay_banner() -> void:
	_frame(Rect2(210.0, 44.0, 220.0, 17.0), "red")
	_text_c(320.0, 48.0, "REPLAY: BEFORE IT WOKE", 15)


# ---------------------------------------------------------------- seller

func _draw_seller(r: RunState) -> void:
	var cust: Dictionary = r.customer
	var tools: Array = cust["tools"] as Array
	var live: bool = not game.is_replaying()
	var est: Dictionary = r.estimate()
	_frame(Rect2(78.0, 196.0, 112.0, 22.0), "note")
	_text_c(134.0, 203.0, ShopGame.ui_estimate_text(est), 0, 1, false)
	for i: int in range(Catalog.TOOLS.size()):
		var tool: String = Catalog.TOOLS[i]
		var rc := Rect2(TOOL_X0 + TOOL_STEP * float(i), TOOL_Y, TOOL_SIZE, TOOL_SIZE)
		var used: bool = tools.has(tool)
		var id: String = "tool:" + tool
		_add(id, rc, live and not used)
		var kind: String = UiFrames.ui_button_kind(false, live and not used, game.hover_id == id, game.down_id == id, _hov_age)
		var sunk: bool = game.down_id == id and live and not used
		_frame(rc, kind)
		var tex: ImageTexture = _tool_icon(tool)
		var ip: Vector2 = rc.position + ((rc.size - tex.get_size()) * 0.5).floor() + (Vector2(0.0, 1.0) if sunk else Vector2.ZERO)
		draw_texture(tex, ip, _c(3) if used else Color.WHITE)
		_text(rc.position + Vector2(3.0, 20.0), "%d" % (i + 1), 15 if not used else 4)
	var cap: int = r.max_wager()
	var card_up: bool = game.room != null and game.room.has_card()
	if live and not card_up:
		var deck_id := "tarot"
		_add(deck_id, DECK_RECT, cap >= 1)
		if _deck_tex == null:
			_deck_tex = SpriteKit.card_texture("", false)
		var hot: bool = cap >= 1 and (game.hover_id == deck_id or game.stake_open)
		# the HUD draws above the room, so while a customer walks past the deck the deck and its label step aside
		var clear: float = game.room.customer_clearance(DECK_RECT.position.x - 8.0, DECK_RECT.end.x + 8.0) if game.room != null else 1.0
		var deck_tint: Color = Color.WHITE if cap >= 1 else _c(4)
		deck_tint.a = clear
		if clear > 0.0:
			draw_texture(_deck_tex, DECK_RECT.position + Vector2(0.0, -1.0 if hot else 0.0), deck_tint)
		if clear >= 1.0:
			_text(DECK_RECT.position + Vector2(-8.0, -11.0), "TAROT [T]", 14 if cap >= 1 else 3)
	_draw_tells(r)
	_draw_offer_row(r, live)


func _draw_tells(r: RunState) -> void:
	var x: float = 64.0
	for tool: String in Catalog.TOOLS:
		if not game.tell_texts.has(tool):
			continue
		var body: String = "%s: %s" % [ShopDebug.sd_tool_name(tool).to_upper(), str(game.tell_texts[tool])]
		var lines: PackedStringArray = UiPixelFont.ui_wrap(body, 128)
		if lines.size() > NOTE_LINES:
			lines = lines.slice(0, NOTE_LINES)
			lines[NOTE_LINES - 1] = lines[NOTE_LINES - 1].substr(0, maxi(lines[NOTE_LINES - 1].length() - 2, 1)) + ".."
		var h: float = 9.0 + float(UiPixelFont.LINE_H * lines.size())
		_frame(Rect2(x, COUNTER_FRONT_Y, 140.0, h), "note")
		_rect(Rect2(x + 68.0, COUNTER_FRONT_Y - 2.0, 3.0, 3.0), 0)  # the pin
		_rect(Rect2(x + 68.0, COUNTER_FRONT_Y - 2.0, 2.0, 2.0), 13)
		for i: int in range(lines.size()):
			_text(Vector2(x + 6.0, COUNTER_FRONT_Y + 5.0 + float(UiPixelFont.LINE_H * i)), lines[i], 0, 1, false)
		x += 144.0
	if game.tell_texts.is_empty() and r.customer.get("kind", "") == RunState.SELLER:
		_text(Vector2(82.0, 238.0), "NO TELLS YET. USE A TOOL.", 15)


func _draw_offer_row(r: RunState, live: bool) -> void:
	_frame(OFFER_RECT, "panel")
	var y: float = OFFER_Y
	var h: float = OFFER_H
	var ask: int = int(r.customer["ask"])
	var x: float = 84.0
	_button("dec", Rect2(x, y, 18.0, h), "-", live)
	x += 20.0
	_frame(Rect2(x, y, 52.0, h), "btn_off")
	_coin(Vector2(x + 9.0, y + 10.0))
	_text(Vector2(x + 18.0, y + 7.0), "%d" % game.offer_amount, 11)
	x += 54.0
	_button("inc", Rect2(x, y, 18.0, h), "+", live)
	x += 24.0
	_button("offer", Rect2(x, y, 64.0, h), "OFFER", live, true)
	x += 70.0
	_button("buy", Rect2(x, y, 100.0, h), "BUY AT %d [B]" % ask, live and ask <= r.cash)
	x += 106.0
	_button("pass", Rect2(x, y, 66.0, h), "PASS [P]", live)


# ---------------------------------------------------------------- buyer

func _draw_buyer(r: RunState) -> void:
	var items: Array[Dictionary] = r.sellable()
	var live: bool = not game.is_replaying()
	var want: String = str(r.customer["category"]).to_upper()
	_frame(Rect2(64.0, COUNTER_FRONT_Y, 230.0, 34.0), "note")
	_text(Vector2(72.0, COUNTER_FRONT_Y + 6.0), "WANTS: %s" % want, 0, 1, false)
	_text(Vector2(72.0, COUNTER_FRONT_Y + 17.0), "CLICK A GLOWING ITEM." if not items.is_empty() else "YOU HOLD NOTHING LIKE THAT.", 8, 1, false)
	var rects: Dictionary = game.shelf_rects()
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
	for item: Dictionary in items:
		var uid: int = int(item["uid"])
		if not rects.has(uid):
			continue
		var rc: Rect2 = rects[uid] as Rect2
		var picked: bool = game.selected_uid == uid
		_add("item:%d" % uid, rc, live)
		draw_rect(rc, _c(15 if picked else (11 if pulse > 0.5 else 10)), false, 2.0 if picked else 1.0)
		if picked:
			UiFrames.ui_flame(self, Vector2(rc.get_center().x - 2.0, rc.position.y - 10.0), _t, 0, false, uid)
		if picked or game.hover_id == "item:%d" % uid:
			var tag: String = "SELL %d" % r.sale_price(item)
			var w: float = float(UiPixelFont.ui_width(tag)) + 14.0
			var tr := Rect2(rc.position.x + rc.size.x * 0.5 - w * 0.5, rc.position.y - 26.0, w, 14.0)
			_frame(tr, "note")
			_text(tr.position + Vector2(7.0, 4.0), tag, 0, 1, false)
	_frame(OFFER_RECT, "panel")
	var sel_price: int = 0
	for item: Dictionary in items:
		if int(item["uid"]) == game.selected_uid:
			sel_price = r.sale_price(item)
	var label: String = "SELL FOR %d [ENTER]" % sel_price if game.selected_uid >= 0 else "PICK AN ITEM"
	_button("sell", Rect2(84.0, OFFER_Y, 170.0, OFFER_H), label, live and game.selected_uid >= 0, true)
	_button("pass", Rect2(262.0, OFFER_Y, 112.0, OFFER_H), "DECLINE [P]", live)


# ---------------------------------------------------------------- popups and cards

func _draw_stake(r: RunState) -> void:
	var slide: float = UiMotion.ui_out(_stake_t)
	var rect := Rect2(STAKE_RECT.position + Vector2(0.0, floorf((1.0 - slide) * 22.0)), STAKE_RECT.size)
	var live: bool = game.stake_open
	_frame(rect, "panel")
	_text_c(rect.position.x + rect.size.x * 0.5, rect.position.y + 8.0, "TAROT: STAKE UP TO %d" % r.max_wager(), 11)
	var y: float = rect.position.y + 28.0
	var x: float = rect.position.x + 12.0
	var h: float = OFFER_H
	_stake_btn("stake_dec", Rect2(x, y, 18.0, h), "-", false, live)
	x += 20.0
	_frame(Rect2(x, y, 52.0, h), "btn_off")
	_coin(Vector2(x + 9.0, y + 10.0))
	_text(Vector2(x + 18.0, y + 7.0), "%d" % game.stake_amount, 11)
	x += 54.0
	_stake_btn("stake_inc", Rect2(x, y, 18.0, h), "+", false, live)
	x += 24.0
	_stake_btn("draw", Rect2(x, y, 72.0, h), "DRAW", true, live)
	x += 78.0
	_stake_btn("stake_close", Rect2(x, y, 30.0, h), "X", false, live)


func _stake_btn(id: String, rect: Rect2, label: String, gold: bool, live: bool) -> void:
	if live:
		_button(id, rect, label, true, gold)
	else:
		UiFrames.ui_button(self, rect, label, true, gold, false, false, 9.0, 9.0)


## Colours [main, highlight, lowlight, shadow] of the DISPLAY face for a card tone.
func _card_cols(tone: int) -> PackedInt32Array:
	match tone:
		7:
			return PackedInt32Array([7, 15, 5, 0])
		11:
			return PackedInt32Array([11, 15, 9, 0])
		13:
			return PackedInt32Array([13, 14, 12, 0])
	return PackedInt32Array([14, 15, 3, 0])


## Title cards. A night card drops its letters in one by one with a puff of dust; a wake or loss card bleeds in like
## ink and then twitches; the rest are bevelled display capitals with an ornamental first letter.
func _draw_card(card: Dictionary) -> void:
	var age: float = float(card["age"])
	var open: float = UiMotion.ui_out(age / 0.2)
	var band_h: float = floorf(100.0 * open)
	var band := Rect2(0.0, 180.0 - floorf(band_h * 0.5), ShopGame.VIEW.x, band_h)
	_rect(band, 0)
	if band_h > 6.0:
		_rect(Rect2(band.position.x, band.position.y + 3.0, band.size.x, 1.0), 9)
		_rect(Rect2(band.position.x, band.position.y + 4.0, band.size.x, 1.0), 8)
		_rect(Rect2(band.position.x, band.end.y - 5.0, band.size.x, 1.0), 8)
		_rect(Rect2(band.position.x, band.end.y - 4.0, band.size.x, 1.0), 9)
	if open < 1.0:
		return
	var tone: int = int(card["tone"])
	var title: String = str(card["title"])
	var y: float = band.position.y + 24.0
	var tw: int = UiPixelFont.ui_head_width(title, 3)
	var x: float = floorf(320.0 - float(tw) * 0.5)
	var t0: float = age - 0.2
	if tone == 11:
		UiPixelFont.ui_draw_land(self, Vector2(x, y), title, _c(11), _c(0), _c(14), UiPixelFont.HEAD, 3, t0)
	elif tone == 13:
		if t0 < 1.0:
			UiPixelFont.ui_draw_reveal(self, Vector2(x + 3.0, y + 3.0), title, _c(0), _c(0), UiPixelFont.HEAD, 3, t0 / 1.0, 5)
			UiPixelFont.ui_draw_reveal(self, Vector2(x, y), title, _c(13), _c(12), UiPixelFont.HEAD, 3, t0 / 1.0, 5)
		else:
			var dim: bool = UiMotion.ui_hash(int(_t * 14.0), 8) < 0.12
			UiPixelFont.ui_draw_fx(self, Vector2(x, y), title, _c(12 if dim else 13), UiPixelFont.HEAD, 3, _t, 0.0, 1.0, _c(0))
	else:
		var dw: int = UiPixelFont.ui_display_width(title, 3, true)
		UiPixelFont.ui_display_draw(self, Vector2(floorf(320.0 - float(dw) * 0.5), y + 11.0), title, 3, _card_cols(tone), _t, 0.0, 0.0, true)
	var ramp: Array[int] = [3, 4, 14, 15]
	var fade: float = clampf((t0 - 0.7) / 0.5, 0.0, 0.999)
	_text_c(320.0, band.position.y + 68.0, str(card["sub"]), ramp[int(fade * 4.0)], 1)
	if age > ShopGame.CARD_SKIP_AFTER + 0.5 and fmod(_t, 1.2) < 0.8:
		_text_c(320.0, band.end.y - 17.0, "CLICK TO SKIP", 3, 1, false)


func _draw_end(r: RunState) -> void:
	var won: bool = game.run.won
	_rect(Rect2(Vector2.ZERO, ShopGame.VIEW), 0)
	_frame(END_RECT, "panel")
	var cx: float = END_RECT.position.x + END_RECT.size.x * 0.5
	var title: String = "YOU SURVIVED" if won else "THE SHOP IS LOST"
	var dw: int = UiPixelFont.ui_display_width(title, 3, true)
	UiPixelFont.ui_display_draw(self, Vector2(floorf(cx - float(dw) * 0.5), END_RECT.position.y + 34.0), title, 3,
		_card_cols(7 if won else 13), _t, 0.0, 0.0 if won else 0.6, true)
	var y: float = END_RECT.position.y + 84.0
	var sub: String = "%d COINS AFTER %d NIGHTS" % [r.cash, r.night] if won else "NIGHT %d. RENT UNPAID." % r.night
	_text_c(cx, y, sub, 14)
	if won:
		y += 14.0
		_text_c(cx, y, "A FREE RELIQUARY WAITS ON THE COUNTER.", 11)
	var finds: Array[Dictionary] = UiOccult.find_rows(UiOccult.run_finds(game.run))
	y += 16.0 if not finds.is_empty() else 22.0
	if not finds.is_empty():
		y = _draw_finds(finds, y, cx)
	_text_c(cx, y, "PASS YOUR WORST OBJECT ON TO A FRIEND", 15)
	y += 16.0
	var field := Rect2(END_RECT.position.x + 18.0, y, END_RECT.size.x - 36.0, 17.0)
	_frame(field, "note")
	var shown: String = game.handle + ("_" if fmod(_t, 1.0) < 0.5 else " ")
	_text(field.position + Vector2(8.0, 5.0), "SIGNED: %s" % shown if game.handle != "" else "TYPE YOUR NAME TO SIGN IT_", 0 if game.handle != "" else 8, 1, false)
	y += 23.0
	var code: String = game.pass_text()
	var box := Rect2(field.position.x, y, field.size.x, 56.0 if finds.is_empty() else 38.0)
	_frame(box, "ledger")
	if code == "":
		_text(box.position + Vector2(float(UiFrames.LEDGER_TEXT_X), 5.0), "NOTHING LEFT TO PASS ON.", 0, 1, false)
	else:
		var lines: PackedStringArray = UiPixelFont.ui_wrap(code, int(box.size.x) - UiFrames.LEDGER_TEXT_X - 8)
		var rows: int = 5 if finds.is_empty() else 3
		for i: int in range(mini(lines.size(), rows)):
			var ln: String = lines[i] if i < rows - 1 or lines.size() <= rows else lines[i].substr(0, lines[i].length() - 2) + ".."
			_text(box.position + Vector2(float(UiFrames.LEDGER_TEXT_X), 5.0 + float(UiPixelFont.LINE_H * i)), ln, 0, 1, false)
	y += box.size.y + 8.0
	_button("copy", Rect2(field.position.x, y, 70.0, 19.0), "COPY", code != "")
	_button("paste", Rect2(field.position.x + 78.0, y, 210.0, 19.0), "PASTE A FRIEND'S LINK")
	y += 26.0
	var status: String = game.gift_status if game.gift_status != "" else "A FRIEND'S LINK STARTS YOUR NEXT RUN WITH THEIR OBJECT."
	var st_lines: PackedStringArray = UiPixelFont.ui_wrap(status, int(field.size.x))
	for i: int in range(mini(2, st_lines.size())):
		_text(Vector2(field.position.x, y + float(UiPixelFont.LINE_H * i)), st_lines[i], 14)
	_button("newrun", Rect2(cx - 80.0, END_RECT.end.y - 36.0, 160.0, 24.0), "NEW RUN [ENTER]", true, true)


## The run-end "FOUND THIS RUN" strip: a header, then each find as a coloured name (pages gold, curios by rarity),
## each sliding in a beat after the one before. Returns the y below it.
func _draw_finds(finds: Array[Dictionary], y: float, cx: float) -> float:
	var x0: float = END_RECT.position.x + 18.0
	_rect(Rect2(x0, y, END_RECT.size.x - 36.0, 1.0), 8)
	_text(Vector2(x0, y + 4.0), "FOUND THIS RUN: %d" % finds.size(), 11)
	var x: float = x0 + 120.0
	var row: float = y + 4.0
	for i: int in range(finds.size()):
		var f: Dictionary = finds[i]
		var shown: float = UiMotion.ui_out((_t - 0.25 * float(i)) / 0.3)
		var nm: String = str(f["name"]).to_upper()
		var w: float = float(UiPixelFont.ui_width(nm)) + 12.0
		if x + w > END_RECT.end.x - 18.0:
			x = x0 + 4.0
			row += 11.0
		if shown > 0.0 and row < y + 26.0:
			var gem: int = int(f["col"])
			_rect(Rect2(x, row + 2.0 - (1.0 - shown) * 4.0, 4.0, 4.0), gem)
			_text(Vector2(x + 7.0, row - (1.0 - shown) * 4.0), nm, gem if shown > 0.5 else 4, 1, true)
		x += w + 4.0
	return y + 30.0
