extends SceneTree
## Contact sheet of the player UI: night card, seller, tell note, buyer with glowing shelf item, tarot stake, wake
## card, end screens (won, lost) and a swatch cell (frames, brass buttons, the three fonts, text effects, Dread candles).
## The window is 1280x720 (exact 2x), so the 640x360 grid downsizes without blur:
## xvfb-run -a godot --path . -s res://tests/shots/ui_sheet.gd -- --scripted
## Writes /tmp/shots/ui_sheet.png. Never touches player data.

const OUT_PATH: String = "/tmp/shots/ui_sheet.png"
const CELL := Vector2i(640, 360)
const LABEL_H: int = 16
const COLS: int = 3

var _game: Variant  # untyped: ShopGame names the Flags autoload, which a -s script cannot see at parse time
var _cells: Array[Image] = []
var _names: Array[String] = []


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _snap(label: String) -> void:
	await _frames(4)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	_cells.append(img)
	_names.append(label)
	print("CELL %s" % label)
	print("t=%d" % Time.get_ticks_msec())


func _play_to_end(seed_in: int, style: String) -> RunState:
	var cat: Catalog = Catalog.load_default()
	var run := RunState.new()
	run.start(seed_in, cat, Tuning.new())
	var bot := ShopBot.new(style)
	var guard: int = 0
	while not run.is_over() and guard < 5000:
		run.apply(bot.decide(run))
		guard += 1
	return run


func _find_end(want_won: bool) -> Vector2i:
	for s: int in range(1, 80):
		for i: int in range(ShopBot.STYLES.size()):
			var r: RunState = _play_to_end(s, ShopBot.STYLES[i])
			if r.won == want_won:
				return Vector2i(s, i)
	return Vector2i(1, 0)


func _find_cursed_seller() -> int:
	var cat: Catalog = Catalog.load_default()
	for s: int in range(1, 80):
		var run := RunState.new()
		run.start(s, cat, Tuning.new())
		if str(run.customer.get("kind", "")) == RunState.SELLER and str((run.customer["item"] as Dictionary)["curse"]) != "":
			return s
	return 1


func _buyer_seed() -> int:
	var cat: Catalog = Catalog.load_default()
	var bot := ShopBot.new(ShopBot.GREEDY)
	for s: int in range(1, 40):
		var run := RunState.new()
		run.start(s, cat, Tuning.new())
		var guard: int = 0
		while not run.is_over() and guard < 600:
			if str(run.customer.get("kind", "")) == RunState.BUYER and run.sellable().size() >= 2:
				return s
			run.apply(bot.decide(run))
			guard += 1
	return 1


func _drive_to_buyer(seed_in: int) -> void:
	var bot := ShopBot.new(ShopBot.GREEDY)
	_game.room.settle_visuals()
	_game.new_run(seed_in)
	while not _game.run.is_over():
		if str(_game.run.customer.get("kind", "")) == RunState.BUYER and _game.run.sellable().size() >= 2:
			return
		_game.act(bot.decide(_game.run))
		_game.room.settle_visuals()  # room bug: a sale during a slide frees a body the slide still holds


func _go() -> void:
	_game = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await _frames(20)
	print("WINDOW %s" % str(root.get_viewport().get_visible_rect().size))
	var st: int = _find_cursed_seller()
	_game.new_run(st)
	await _frames(2)
	_game.cards[0]["age"] = 0.5
	await _snap("night card, letters landing")
	_game.cards.clear()
	_game.room.settle_visuals()
	_game.hints.age = 0.12
	_game.hud.ui_pop(-12)
	_game.log_age[_game.log_age.size() - 1] = 0.3
	await _snap("seller: pinned hint fluttering, log writing, cash pop")
	for tool: String in Catalog.TOOLS:
		if _game.tell_texts.is_empty():
			_game.activate("tool:" + tool)
	_game.room.settle_visuals()
	_game.hover_id = "offer"
	_game.hints.dismiss()
	_game.log_age[_game.log_age.size() - 1] = 9.0
	await _snap("tell note, ledger log, hover")
	_drive_to_buyer(_buyer_seed())
	_game.cards.clear()
	await _frames(100)
	var items: Array = _game.run.sellable()
	if not items.is_empty():
		_game.selected_uid = int(items[0]["uid"])
	await _snap("buyer, glowing shelf")
	_game.room.settle_visuals()
	_game.new_run(st)
	_game.cards.clear()
	_game.room.settle_visuals()
	_game.stake_open = true
	if _game.run.max_wager() < 1:
		_game.run.cash = 40
	_game.run.dread = _game.run.tuning.wake_threshold * 0.8
	await _frames(20)
	await _snap("tarot stake, Dread candle guttering")
	_game.stake_open = false
	_game.push_card("SOMETHING WOKE", "THE MUSIC BOX SHATTERED", 13)
	_game.cards[0]["age"] = 0.85
	await _snap("wake card, ink bleeding in")
	var won: Vector2i = _find_end(true)
	_game.room.settle_visuals()
	_game.new_run(won.x)
	var bot_w := ShopBot.new(ShopBot.STYLES[won.y])
	while not _game.run.is_over():
		_game.act(bot_w.decide(_game.run))
		_game.room.settle_visuals()
	_game.cards.clear()
	_game.handle = "MORTIMER"
	await _snap("end, won")
	var lost: Vector2i = _find_end(false)
	_game.room.settle_visuals()
	_game.new_run(lost.x)
	var bot_l := ShopBot.new(ShopBot.STYLES[lost.y])
	while not _game.run.is_over():
		_game.act(bot_l.decide(_game.run))
		_game.room.settle_visuals()
	_game.cards.clear()
	_game.handle = ""
	await _snap("end, lost")
	var sw := _Swatch.new()
	root.add_child(sw)
	await _snap("swatch: frames, fonts, effects, candles")
	_save_sheet()


func _save_sheet() -> void:
	var rows: int = int(ceil(float(_cells.size()) / float(COLS)))
	var size := Vector2i(COLS * CELL.x, rows * (CELL.y + LABEL_H))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.size = Vector2(size)
	vp.add_child(bg)
	for i: int in range(_cells.size()):
		var x: int = (i % COLS) * CELL.x
		var y: int = (i / COLS) * (CELL.y + LABEL_H)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(_cells[i])
		tr.position = Vector2(x, y + LABEL_H)
		vp.add_child(tr)
		var lb := Label.new()
		lb.text = "%d. %s" % [i + 1, _names[i]]
		lb.position = Vector2(x + 4, y)
		lb.add_theme_font_size_override("font_size", 12)
		vp.add_child(lb)
	await _frames(3)
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	img.save_png(OUT_PATH)
	print("SHEET %s %dx%d" % [OUT_PATH, img.get_width(), img.get_height()])
	quit()


## Frames, brass buttons in every state, the three fonts, the text effects and the Dread candle at five levels, drawn
## on the 640x360 grid at a fixed clock so the sheet is repeatable. Only classes that never touch Flags.
class _Swatch extends Control:
	var t: float = 1.3
	var pal: PackedColorArray = RoomPalette.colors()

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _body(p: Vector2, s: String, col: int) -> void:
		UiPixelFont.ui_draw(self, p, s, pal[col], 1, true, pal[0])

	func _draw() -> void:
		var s: float = minf(size.x / 640.0, size.y / 360.0)
		draw_set_transform((size - Vector2(640.0, 360.0) * s) * 0.5, 0.0, Vector2(s, s))
		draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), pal[1])
		UiFrames.ui_draw(self, Rect2(8.0, 6.0, 120.0, 40.0), "panel")
		_body(Vector2(20.0, 20.0), "BLACKENED WOOD", 14)
		UiFrames.ui_draw(self, Rect2(136.0, 6.0, 120.0, 40.0), "note")
		UiPixelFont.ui_draw(self, Vector2(146.0, 14.0), "Aged parchment", pal[0], 1, false)
		UiPixelFont.ui_draw(self, Vector2(146.0, 26.0), "gypsy jug, quay", pal[8], 1, false)
		UiFrames.ui_draw(self, Rect2(264.0, 6.0, 190.0, 40.0), "ledger")
		UiPixelFont.ui_draw(self, Vector2(281.0, 11.0), "Night 1 begins. Rent due", pal[8], 1, false)
		UiPixelFont.ui_draw_ink(self, Vector2(281.0, 21.0), "Fence arrives, asking 38.", pal[0], pal[12], 17, true, pal[0], t)
		UiFrames.ui_draw(self, Rect2(462.0, 6.0, 80.0, 40.0), "red")
		UiFrames.ui_draw(self, Rect2(550.0, 6.0, 82.0, 40.0), "glow")
		var labels: Array[String] = ["BRASS", "HOVER", "PRESSED", "SQUISH", "OFFER", "GOLD DOWN", "OFF"]
		for i: int in range(labels.size()):
			var r := Rect2(8.0 + 90.0 * float(i), 54.0, 82.0, 21.0)
			var gold: bool = i >= 4 and i <= 5
			UiFrames.ui_button(self, r, labels[i], i != 6, gold, i == 1, i == 2 or i == 3 or i == 5, 5.0, 1.0 if i != 3 else 0.03)
		UiFrames.ui_flame(self, Vector2(420.0, 90.0), 0.0, 0, false, 5)
		UiFrames.ui_flame(self, Vector2(430.0, 90.0), 0.25, 0, false, 5)
		UiFrames.ui_flame(self, Vector2(440.0, 90.0), 0.5, 1, false, 5)
		UiFrames.ui_flame(self, Vector2(450.0, 90.0), 0.5, 2, true, 5)
		_body(Vector2(8.0, 84.0), "Body 5x7: quick brown fox, jumpy gypsy; pq 0123.", 15)
		UiPixelFont.ui_head_draw(self, Vector2(8.0, 100.0), "HEAD: THE QUICK BROWN FOX 0123456789", pal[11], 1, true, pal[0])
		UiPixelFont.ui_head_draw(self, Vector2(8.0, 118.0), "SETTINGS PAUSED", pal[14], 2, true, pal[0])
		var cols := PackedInt32Array([11, 15, 9, 12])
		UiPixelFont.ui_display_draw(self, Vector2(10.0, 176.0), "CURSED PAWN", 3, cols, t, 0.0, 0.0, true)
		UiPixelFont.ui_display_draw(self, Vector2(10.0, 222.0), "SOMETHING WOKE", 2, PackedInt32Array([13, 14, 12, 0]), t, 0.0, 0.0, true)
		draw_rect(Rect2(340.0, 110.0, 292.0, 128.0), pal[0])
		UiPixelFont.ui_draw_reveal(self, Vector2(346.0, 116.0), "SOMETHING WOKE", pal[13], pal[12], UiPixelFont.HEAD, 2, 0.5, 5)
		UiPixelFont.ui_draw_fx(self, Vector2(346.0, 140.0), "SOMETHING WOKE", pal[13], UiPixelFont.HEAD, 2, 1.1, 0.0, 1.0, pal[0])
		UiPixelFont.ui_draw_land(self, Vector2(346.0, 168.0), "NIGHT 1 BEGINS", pal[11], pal[0], pal[14], UiPixelFont.HEAD, 2, 0.5)
		UiPixelFont.ui_draw_fx(self, Vector2(346.0, 196.0), "WAVE THE SHOP", pal[14], UiPixelFont.HEAD, 2, t, 1.0, 0.0, pal[0])
		_body(Vector2(346.0, 222.0), "bleed / jitter / land / wave", 4)
		var fracs: Array[float] = [0.0, 0.4, 0.6, 0.85, 1.0]
		for i: int in range(fracs.size()):
			var px: float = 12.0 + 74.0 * float(i)
			UiFrames.ui_draw(self, Rect2(px, 262.0, 42.0, 68.0), "panel")
			var cx: float = px + 21.0
			var h: int = 3 + int(round(35.0 * (1.0 - fracs[i])))
			var fs: int = -1 if fracs[i] >= 1.0 else (0 if fracs[i] < 0.5 else (1 if fracs[i] < 0.75 else 2))
			UiFrames.ui_candle(self, cx, 322.0, 8, h, t, fs, fracs[i] >= 0.75, 2)
			if fracs[i] >= 0.4 and fracs[i] < 1.0:
				draw_rect(Rect2(cx + 2.0, 322.0 - float(h) + 6.0 + 8.0 * fracs[i], 1.0, 2.0), pal[15])
			_text_small(Vector2(px + 4.0, 334.0), "%d%%" % int(fracs[i] * 100.0))
		UiFrames.ui_draw(self, Rect2(400.0, 252.0, 232.0, 46.0), "ledger")
		UiPixelFont.ui_draw(self, Vector2(417.0, 257.0), "Hooded fence arrives with Hand bell.", pal[8], 1, false)
		draw_rect(Rect2(415.0, 266.0, 150.0, 9.0), pal[11])
		UiPixelFont.ui_draw_ink(self, Vector2(417.0, 267.0), "You buy it for 9. It is warm.", pal[0], pal[12], 21, true, pal[0], t)
		_body(Vector2(404.0, 306.0), "+12", 7)
		_body(Vector2(428.0, 306.0), "-40", 13)
		_body(Vector2(452.0, 306.0), "floating cash", 14)

	func _text_small(p: Vector2, s: String) -> void:
		UiPixelFont.ui_draw(self, p, s, pal[14], 1, true, pal[0])
