extends SceneTree
## Contact sheet of the player UI: night card, seller, tell note, buyer with glowing shelf item, tarot stake, wake
## card, end screens (won, lost). The window is 1920x1080 (exact 4x), so the 480x270 grid downsizes without blur:
## xvfb-run -a godot --path . --resolution 960x540 -s res://tests/shots/ui_sheet.gd -- --scripted
## Writes /tmp/shots/ui_sheet.png. Never touches player data.

const OUT_PATH: String = "/tmp/shots/ui_sheet.png"
const CELL := Vector2i(480, 270)
const LABEL_H: int = 16
const COLS: int = 4

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
	_game.cards[0]["age"] = 0.6
	await _snap("night card")
	_game.cards.clear()
	_game.room.settle_visuals()
	await _snap("seller at counter")
	for tool: String in Catalog.TOOLS:
		if _game.tell_texts.is_empty():
			_game.activate("tool:" + tool)
	_game.room.settle_visuals()
	_game.hover_id = "offer"
	await _snap("after inspect, tell note")
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
	_game.toggle_tarot()
	await _snap("tarot stake")
	_game.stake_open = false
	_game.push_card("SOMETHING WOKE", "THE MUSIC BOX SHATTERED", 13)
	_game.cards[0]["age"] = 0.6
	await _snap("wake card")
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
