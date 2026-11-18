class_name UiHud
extends Control
## Draws the whole shop screen at 480x270 (inside a SubViewport) from a ShopGame's state, and keeps the clickable
## widget list the draw pass built so the game can hit-test mouse positions. Palette indices (RoomPalette):
## 0 black, 1-4 purples, 5-7 greens, 8 dark wood, 9 wood, 10 amber, 11 candle yellow, 12 dark red, 13 red,
## 14 bone grey, 15 bone white.

const TOP_H: float = 15.0
const COUNTER_FRONT_Y: float = 171.0
const TOOL_X0: float = 150.0
const TOOL_Y: float = 144.0
const TOOL_STEP: float = 29.0
const DECK_RECT := Rect2(300.0, 128.0, 24.0, 40.0)
const OFFER_Y: float = 205.0
const LOG_RECT := Rect2(4.0, 234.0, 332.0, 32.0)
const LOG_LINES: int = 3
const STAKE_RECT := Rect2(128.0, 92.0, 206.0, 50.0)
const END_RECT := Rect2(76.0, 22.0, 328.0, 226.0)

var game: ShopGame
var widgets: Array[Dictionary] = []  ## {id, rect, enabled} in draw order; the last containing a point wins
var _t: float = 0.0
var _pal: PackedColorArray = RoomPalette.colors()
var _tool_tex: Dictionary = {}
var _deck_tex: ImageTexture


func _init() -> void:
	name = "UiHud"
	size = ShopGame.VIEW
	custom_minimum_size = ShopGame.VIEW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The topmost enabled-or-not widget id under p (UI grid coordinates), "" for none.
func widget_at(p: Vector2) -> String:
	for i: int in range(widgets.size() - 1, -1, -1):
		if (widgets[i]["rect"] as Rect2).has_point(p):
			return str(widgets[i]["id"]) if bool(widgets[i]["enabled"]) else ""
	return ""


func _process(delta: float) -> void:
	_t += delta


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


func _coin(c: Vector2) -> void:
	_rect(Rect2(c.x - 2.0, c.y - 3.0, 5.0, 7.0), 0)
	_rect(Rect2(c.x - 3.0, c.y - 2.0, 7.0, 5.0), 0)
	_rect(Rect2(c.x - 2.0, c.y - 2.0, 5.0, 5.0), 10)
	_rect(Rect2(c.x - 1.0, c.y - 2.0, 2.0, 1.0), 11)
	_rect(Rect2(c.x, c.y - 1.0, 1.0, 3.0), 9)


func _add(id: String, rect: Rect2, enabled: bool = true) -> void:
	widgets.append({"id": id, "rect": rect, "enabled": enabled})


## A framed text button; hover and pressed states come from the game.
func _button(id: String, rect: Rect2, label: String, enabled: bool = true, gold: bool = false) -> void:
	_add(id, rect, enabled)
	var kind: String = "gold" if gold else "btn"
	var col: int = 0 if gold else 15
	if not enabled:
		kind = "btn_off"
		col = 3
	elif game.down_id == id:
		kind += "_down"
	elif game.hover_id == id:
		kind += "_hover"
	_frame(rect, kind)
	var nudge: float = 1.0 if enabled and game.down_id == id else 0.0
	_text_c(rect.position.x + rect.size.x * 0.5, rect.position.y + (rect.size.y - 7.0) * 0.5 + nudge, label, col, 1,
		not gold and enabled)


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
	if game != null and game.hints != null:
		TsHintFrame.ts_draw(self, game.hints.text(), game.hints.age)
	if game.end_panel_visible():
		_draw_log()
		widgets.clear()
		_draw_end(r)
		return
	if not r.customer.is_empty():
		if str(r.customer["kind"]) == RunState.SELLER:
			_draw_seller(r)
		else:
			_draw_buyer(r)
	else:
		_text(Vector2(64.0, 190.0), "THE SHOP IS QUIET...", 14)
	_draw_log()
	_draw_side_buttons(r)
	if game.stake_open and not game.is_replaying():
		_draw_stake(r)
	if game.is_replaying():
		_draw_replay_banner()
	if not game.cards.is_empty():
		widgets.clear()
		_draw_card(game.cards[0])


func _draw_top(r: RunState) -> void:
	_frame(Rect2(0.0, 0.0, ShopGame.VIEW.x, TOP_H), "panel")
	_text(Vector2(6.0, 4.0), "NIGHT %d/%d" % [r.night, int(r.tuning.nights)], 15)
	_text(Vector2(74.0, 4.0), ShopGame.ui_clock_text(r.clock), 14)
	_coin(Vector2(144.0, 7.0))
	_text(Vector2(151.0, 4.0), "%d" % r.cash, 11)
	_text(Vector2(190.0, 4.0), "RENT %d" % r.rent_for(r.night), 15 if r.cash >= r.rent_for(r.night) else 13)
	_text(Vector2(262.0, 4.0), "DREAD", 14)
	_draw_dread(r, Rect2(296.0, 4.0, 178.0, 8.0))


func _draw_dread(r: RunState, bar: Rect2) -> void:
	var thr: float = maxf(r.tuning.wake_threshold, 0.1)
	var frac: float = clampf(r.dread / thr, 0.0, 1.0)
	_rect(bar.grow(1.0), 3)
	_rect(bar, 0)
	var fill_col: int = 6 if frac < 0.5 else (10 if frac < 0.8 else 13)
	_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), fill_col)
	_rect(Rect2(bar.position, Vector2(bar.size.x * frac, 1.0)), fill_col + 1 if fill_col < 13 else 14)
	for i: int in range(1, 8):
		_rect(Rect2(bar.position.x + bar.size.x * float(i) / 8.0, bar.position.y, 1.0, bar.size.y), 0)
	if frac >= 0.75:
		var on: bool = fmod(_t * (3.0 + 5.0 * frac), 1.0) < 0.5
		if on:
			draw_rect(bar.grow(1.0), _c(15 if frac >= 1.0 else 13), false, 1.0)


func _draw_log() -> void:
	_frame(LOG_RECT, "note")
	var lines := PackedStringArray()
	for l: String in game.log_lines:
		lines.append_array(UiPixelFont.ui_wrap(l, int(LOG_RECT.size.x) - 10))
	var first: int = maxi(lines.size() - LOG_LINES, 0)
	for i: int in range(first, lines.size()):
		var age: int = lines.size() - 1 - i
		_text(Vector2(LOG_RECT.position.x + 5.0, LOG_RECT.position.y + 5.0 + float(i - first) * 8.0), lines[i],
			0 if age == 0 else 8, 1, false)


func _draw_side_buttons(r: RunState) -> void:
	var can_replay: bool = game.rec != null and not game.rec.wake_at.is_empty() and not game.is_replaying()
	_button("replay", Rect2(340.0, 236.0, 66.0, 14.0), "REPLAY [R]", can_replay)
	_button("relics", Rect2(410.0, 236.0, 66.0, 14.0), "RELIQUARY")
	_text(Vector2(346.0, 256.0), "HELD %d" % r.inventory.size(), 14)
	_text(Vector2(406.0, 256.0), "SEED %d" % game.seed_now, 3)


func _draw_replay_banner() -> void:
	_frame(Rect2(150.0, 20.0, 180.0, 14.0), "red")
	_text_c(240.0, 23.0, "REPLAY: BEFORE IT WOKE", 15)


# ---------------------------------------------------------------- seller

func _draw_seller(r: RunState) -> void:
	var cust: Dictionary = r.customer
	var tools: Array = cust["tools"] as Array
	var live: bool = not game.is_replaying()
	var est: Dictionary = r.estimate()
	_frame(Rect2(60.0, 148.0, 84.0, 17.0), "note")
	_text_c(102.0, 153.0, ShopGame.ui_estimate_text(est), 0, 1, false)
	for i: int in range(Catalog.TOOLS.size()):
		var tool: String = Catalog.TOOLS[i]
		var rc := Rect2(TOOL_X0 + TOOL_STEP * float(i), TOOL_Y, 26.0, 26.0)
		var used: bool = tools.has(tool)
		var id: String = "tool:" + tool
		_add(id, rc, live and not used)
		var kind: String = "btn_off" if used else ("btn_down" if game.down_id == id else ("btn_hover" if game.hover_id == id else "btn"))
		_frame(rc, kind)
		draw_texture(_tool_icon(tool), rc.position + Vector2(1.0, 1.0), _c(3) if used else Color.WHITE)
		_text(rc.position + Vector2(3.0, 18.0), "%d" % (i + 1), 15 if not used else 4)
	var cap: int = r.max_wager()
	var card_up: bool = game.room != null and game.room.has_card()
	if live and not card_up:
		var deck_id := "tarot"
		_add(deck_id, DECK_RECT, cap >= 1)
		if _deck_tex == null:
			_deck_tex = SpriteKit.card_texture("", false)
		var hot: bool = cap >= 1 and (game.hover_id == deck_id or game.stake_open)
		draw_texture(_deck_tex, DECK_RECT.position + Vector2(0.0, -1.0 if hot else 0.0), Color.WHITE if cap >= 1 else _c(4))
		_text(DECK_RECT.position + Vector2(-6.0, -10.0), "TAROT [T]", 14 if cap >= 1 else 3)
	_draw_tells(r)
	_draw_offer_row(r, live)


func _draw_tells(r: RunState) -> void:
	var x: float = 60.0
	for tool: String in Catalog.TOOLS:
		if not game.tell_texts.has(tool):
			continue
		var body: String = "%s: %s" % [ShopDebug.sd_tool_name(tool).to_upper(), str(game.tell_texts[tool])]
		var lines: PackedStringArray = UiPixelFont.ui_wrap(body, 112)
		var h: float = 6.0 + 8.0 * float(lines.size())
		_frame(Rect2(x, COUNTER_FRONT_Y, 120.0, h), "note")
		_rect(Rect2(x + 54.0, COUNTER_FRONT_Y - 1.0, 12.0, 3.0), 13)  # the pin
		for i: int in range(lines.size()):
			_text(Vector2(x + 4.0, COUNTER_FRONT_Y + 4.0 + 8.0 * float(i)), lines[i], 0, 1, false)
		x += 124.0
	if game.tell_texts.is_empty() and r.customer.get("kind", "") == RunState.SELLER:
		_text(Vector2(62.0, 180.0), "NO TELLS YET. USE A TOOL.", 15)


func _draw_offer_row(r: RunState, live: bool) -> void:
	_frame(Rect2(58.0, OFFER_Y - 2.0, 308.0, 24.0), "panel")
	var y: float = OFFER_Y + 1.0
	var h: float = 17.0
	var ask: int = int(r.customer["ask"])
	var x: float = 63.0
	_button("dec", Rect2(x, y, 14.0, h), "-", live)
	x += 16.0
	_frame(Rect2(x, y, 44.0, h), "btn_off")
	_coin(Vector2(x + 7.0, y + 8.0))
	_text(Vector2(x + 14.0, y + 5.0), "%d" % game.offer_amount, 11)
	x += 46.0
	_button("inc", Rect2(x, y, 14.0, h), "+", live)
	x += 18.0
	_button("offer", Rect2(x, y, 58.0, h), "OFFER", live, true)
	x += 62.0
	_button("buy", Rect2(x, y, 84.0, h), "BUY AT %d [B]" % ask, live and ask <= r.cash)
	x += 88.0
	_button("pass", Rect2(x, y, 56.0, h), "PASS [P]", live)


# ---------------------------------------------------------------- buyer

func _draw_buyer(r: RunState) -> void:
	var items: Array[Dictionary] = r.sellable()
	var live: bool = not game.is_replaying()
	var want: String = str(r.customer["category"]).to_upper()
	_frame(Rect2(60.0, 176.0, 190.0, 24.0), "note")
	_text(Vector2(66.0, 181.0), "WANTS: %s" % want, 0, 1, false)
	_text(Vector2(66.0, 190.0), "CLICK A GLOWING ITEM." if not items.is_empty() else "YOU HOLD NOTHING LIKE THAT.", 8, 1, false)
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
		if picked or game.hover_id == "item:%d" % uid:
			var tag: String = "SELL %d" % r.sale_price(item)
			var w: float = float(UiPixelFont.ui_width(tag)) + 10.0
			var tr := Rect2(rc.position.x + rc.size.x * 0.5 - w * 0.5, rc.position.y - 14.0, w, 12.0)
			_frame(tr, "note")
			_text(tr.position + Vector2(5.0, 3.0), tag, 0, 1, false)
	_frame(Rect2(58.0, OFFER_Y - 2.0, 308.0, 24.0), "panel")
	var sel_price: int = 0
	for item: Dictionary in items:
		if int(item["uid"]) == game.selected_uid:
			sel_price = r.sale_price(item)
	var label: String = "SELL FOR %d [ENTER]" % sel_price if game.selected_uid >= 0 else "PICK AN ITEM"
	_button("sell", Rect2(63.0, OFFER_Y + 1.0, 150.0, 17.0), label, live and game.selected_uid >= 0, true)
	_button("pass", Rect2(220.0, OFFER_Y + 1.0, 100.0, 17.0), "DECLINE [P]", live)


# ---------------------------------------------------------------- popups and cards

func _draw_stake(r: RunState) -> void:
	_frame(STAKE_RECT, "panel")
	_text_c(STAKE_RECT.position.x + STAKE_RECT.size.x * 0.5, STAKE_RECT.position.y + 6.0,
		"TAROT: STAKE UP TO %d" % r.max_wager(), 11)
	var y: float = STAKE_RECT.position.y + 22.0
	var x: float = STAKE_RECT.position.x + 8.0
	_button("stake_dec", Rect2(x, y, 14.0, 17.0), "-")
	x += 16.0
	_frame(Rect2(x, y, 44.0, 17.0), "btn_off")
	_coin(Vector2(x + 7.0, y + 8.0))
	_text(Vector2(x + 14.0, y + 5.0), "%d" % game.stake_amount, 11)
	x += 46.0
	_button("stake_inc", Rect2(x, y, 14.0, 17.0), "+")
	x += 18.0
	_button("draw", Rect2(x, y, 62.0, 17.0), "DRAW", true, true)
	x += 66.0
	_button("stake_close", Rect2(x, y, 26.0, 17.0), "X")


func _draw_card(card: Dictionary) -> void:
	var age: float = float(card["age"])
	var slide: float = clampf(age / 0.15, 0.0, 1.0)
	var band := Rect2(0.0, 96.0 + (1.0 - slide) * 12.0, ShopGame.VIEW.x, 76.0)
	_rect(band, 0)
	_rect(Rect2(band.position.x, band.position.y + 2.0, band.size.x, 1.0), 9)
	_rect(Rect2(band.position.x, band.end.y - 3.0, band.size.x, 1.0), 9)
	var tone: int = int(card["tone"])
	_text_c(240.0, band.position.y + 16.0, str(card["title"]), tone, 3)
	_text_c(240.0, band.position.y + 48.0, str(card["sub"]), 15, 1)
	if age > ShopGame.CARD_SKIP_AFTER:
		_text_c(240.0, band.position.y + 62.0, "CLICK TO SKIP", 3, 1, false)


func _draw_end(r: RunState) -> void:
	var won: bool = game.run.won
	_rect(Rect2(Vector2.ZERO, ShopGame.VIEW), 0)
	_frame(END_RECT, "panel")
	var cx: float = END_RECT.position.x + END_RECT.size.x * 0.5
	var y: float = END_RECT.position.y + 10.0
	_text_c(cx, y, "YOU SURVIVED" if won else "THE SHOP IS LOST", 7 if won else 13, 3)
	y += 28.0
	var sub: String = "%d COINS AFTER %d NIGHTS" % [r.cash, r.night] if won else "NIGHT %d. RENT UNPAID." % r.night
	_text_c(cx, y, sub, 14)
	if won:
		y += 10.0
		_text_c(cx, y, "A FREE RELIQUARY WAITS ON THE COUNTER.", 11)
	y += 16.0
	_text_c(cx, y, "PASS YOUR WORST OBJECT ON TO A FRIEND", 15)
	y += 12.0
	var field := Rect2(END_RECT.position.x + 14.0, y, END_RECT.size.x - 28.0, 13.0)
	_frame(field, "note")
	var shown: String = game.handle + ("_" if fmod(_t, 1.0) < 0.5 else " ")
	_text(field.position + Vector2(5.0, 3.0), "SIGNED: %s" % shown if game.handle != "" else "TYPE YOUR NAME TO SIGN IT_", 0 if game.handle != "" else 8, 1, false)
	y += 17.0
	var code: String = game.pass_text()
	var box := Rect2(field.position.x, y, field.size.x, 42.0)
	_frame(box, "note")
	if code == "":
		_text(box.position + Vector2(6.0, 6.0), "NOTHING LEFT TO PASS ON.", 0, 1, false)
	else:
		var lines: PackedStringArray = UiPixelFont.ui_wrap(code, int(box.size.x) - 12)
		for i: int in range(mini(lines.size(), 4)):
			var ln: String = lines[i] if i < 3 or lines.size() <= 4 else lines[i].substr(0, lines[i].length() - 2) + ".."
			_text(box.position + Vector2(6.0, 5.0 + 8.0 * float(i)), ln, 0, 1, false)
	y += 47.0
	_button("copy", Rect2(field.position.x, y, 62.0, 16.0), "COPY", code != "")
	_button("paste", Rect2(field.position.x + 68.0, y, 190.0, 16.0), "PASTE A FRIEND'S LINK")
	y += 20.0
	var status: String = game.gift_status if game.gift_status != "" else "A FRIEND'S LINK STARTS YOUR NEXT RUN WITH THEIR OBJECT."
	for i: int in range(mini(2, UiPixelFont.ui_wrap(status, int(field.size.x)).size())):
		_text(Vector2(field.position.x, y + 8.0 * float(i)), UiPixelFont.ui_wrap(status, int(field.size.x))[i], 14)
	_button("newrun", Rect2(cx - 70.0, END_RECT.end.y - 30.0, 140.0, 22.0), "NEW RUN [ENTER]", true, true)
