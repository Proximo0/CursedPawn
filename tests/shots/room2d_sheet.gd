extends SceneTree
## Contact sheet of the 2D shop room (640x360): calm, props, bubble stages, tools and the cursed overlay, a card, customers,
## sale sparkles, smoke, Dread 0.3 / 0.5 / 0.7 / 0.9, the wake beat (full and gentle) and the wake. Reports ms per frame.
## Run: xvfb-run -a godot --path . --resolution 1280x720 -s res://tests/shots/room2d_sheet.gd -- --scripted
## Writes /tmp/shots/room2d_sheet.png and prints the mean luminance of each cell. Never touches player data.

const OUT_PATH: String = "/tmp/shots/room2d_sheet.png"
const CELL := Vector2i(427, 240)
const LABEL_H: int = 16
const COLS: int = 3

var _room: ShopRoom2D
var _cells: Array[Image] = []
var _names: Array[String] = []


func _initialize() -> void:
	_go.call_deferred()


func _lum(img: Image) -> float:
	var s: float = 0.0
	var n: int = 0
	for y: int in range(0, img.get_height(), 3):
		for x: int in range(0, img.get_width(), 3):
			var c: Color = img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return s / float(maxi(n, 1))


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _snap(label: String) -> void:
	await _frames(3)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	_cells.append(img)
	_names.append(label)
	print("CELL %-28s lum=%.3f" % [label, _lum(img)])


func _run_with(cat: Catalog, names: PackedStringArray) -> RunState:
	var run := RunState.new()
	run.start(11, cat, Tuning.new())
	run.inventory.clear()
	var uid: int = 100
	for n: String in names:
		for o: Dictionary in cat.objects:
			if str(o["name"]) == n:
				run.inventory.append({"uid": uid, "id": o["id"], "name": n, "category": o["category"], "value": o["value"],
					"curse": "", "est": 30, "tells": 0})
				uid += 1
	return run


func _customer(kind: String, oname: String, tid: String) -> void:
	var ev: Array[Dictionary] = [{"e": "customer", "kind": kind, "name": oname, "category": "toy", "ask": 40, "tid": tid}]
	_room.apply_events(ev)
	_room.settle_visuals()


func _go() -> void:
	var cat: Catalog = Catalog.load_default()
	_room = ShopRoom2D.new()
	root.add_child(_room)
	var ten: PackedStringArray = ["Music box", "Silver locket", "Violin", "Old ledger", "Candlestick", "Porcelain doll",
		"Hand mirror", "Pocket watch", "Teddy bear", "Brass key"]
	var picks: PackedStringArray = []
	for o: Dictionary in cat.objects:
		if picks.size() < 10:
			picks.append(str(o["name"]))
	for n: String in ten:
		if picks.size() < 10 and not picks.has(n):
			picks.append(n)
	await _frames(20)
	_room.setup(_run_with(cat, PackedStringArray()))
	await _snap("calm empty")
	_room.setup(_run_with(cat, picks))
	await _snap("calm, 10 props")
	_customer("seller", picks[0], "widow")
	_room._show_bubble()
	_room._bubble.advance(0.4)
	await _snap("bubble typing (pop+letters)")
	_room._bubble.finish_typing()
	await _snap("bubble full, dread words")
	_room._bubble.close()
	_room._bubble.advance(0.3)
	await _snap("bubble fraying to ash")
	_room._bubble.hide_now()
	for tool: String in ["uv", "scale"]:
		_room.apply_events([{"e": "inspected", "tool": tool, "tell": "glows" if tool == "uv" else "", "estimate": {}}] as Array[Dictionary])
		_room._fx_t = 0.5
		await _frames(1)
		_room._fx_t = 0.5
		await _snap("tool: " + tool + (" + cursed overlay" if tool == "uv" else ""))
	_room.apply_events([{"e": "wager", "card": "The Fool", "stake": 5, "payout": 10, "dread": 1.0}] as Array[Dictionary])
	_room._card_t = 0.5
	_room._update_card(0.05)
	_room._update_card(0.05)
	await _snap("card flip + spark trail")
	_room.apply_events([{"e": "sold", "uid": 100, "name": picks[0], "price": 9, "imposter": false}] as Array[Dictionary])
	_room._fx_sys.update(0.12)
	await _snap("sale: coin sparkles")
	_room._fx_sys.clear()
	_room._cust_state = "here"
	_room.apply_events([{"e": "passed", "kind": "seller"}] as Array[Dictionary])
	_room._fx_sys.update(0.35)
	await _snap("leaving: ink smoke")
	_customer("buyer", "", "priest")
	await _snap("customer: priest (tall)")
	_customer("buyer", "", "haggler")
	await _snap("customer: haggler (short)")
	await _occult_cells(cat, picks)
	var thr: float = Tuning.shared().wake_threshold
	for lvl: float in [0.3, 0.5, 0.7, 0.9]:
		_room.set_dread(lvl * thr)
		_customer("buyer", "", "widow")
		_room._bubble.hide_now()
		await _frames(45)
		await _snap("dread %.1f" % lvl)
	_room.set_dread(0.0)
	_room.setup(_run_with(cat, picks))
	_room.wake(7)
	for mode: int in [1, 0]:
		_room.scare_level = mode
		_room.wake(7)
		while _room._wake_tick < (38 if mode == 1 else 40):
			await physics_frame
		_room.process_mode = Node.PROCESS_MODE_DISABLED
		_room._fx.queue_redraw()
		await _snap("wake beat: silhouette, " + ("FULL" if mode == 1 else "GENTLE"))
		_room.process_mode = Node.PROCESS_MODE_INHERIT
		if mode == 1:
			while _room.is_waking():
				await physics_frame
			await _frames(200)
	_room.scare_level = 1
	_room.setup(_run_with(cat, picks))
	_room.wake(7)
	for target: int in [110, 180]:
		while _room._wake_tick < target and _room.is_waking():
			await physics_frame
		await _snap("wake %.1f s" % (float(target) / 60.0))
	await _measure(cat, picks)
	_save_sheet()


## The occult round: one cell per spell effect, the backfire flash and the Midnight Table lighting.
func _occult_cells(cat: Catalog, picks: PackedStringArray) -> void:
	var cases: Array = [
		["scry_reveal", {"e": "scry_reveal", "tool": "uv", "tell": "glows"}, 25],
		["hexed: chains", {"e": "hexed", "reserve": 10, "ask": 20}, 20],
		["glamoured: gold", {"e": "glamoured", "mult": 1.3}, 30],
		["banished: smoke", {"e": "banished", "uid": 100, "name": picks[0]}, 22],
		["summoned: sigil", {"e": "summoned", "category": "toy"}, 25],
		["sealed: chalk", {"e": "sealed"}, 25],
		["backfire (full)", {"e": "backfire", "spell": "hex", "kind": "dread_spike", "text": "x"}, 2],
		["found_hint: glimmer", {"e": "found_hint", "kind": "curio"}, 20],
		["table_open: green lamp", {"e": "table_open", "night": 1, "games_left": 2, "lots_left": 1}, 60],
	]
	for c: Array in cases:
		_room.setup(_run_with(cat, picks))
		_room.scare_level = 1
		_customer("seller", picks[1], "widow")
		_room._bubble.hide_now()
		await _frames(10)
		_room.apply_events([c[1] as Dictionary] as Array[Dictionary])
		await _frames(int(c[2]))
		await _snap(str(c[0]))
		_room.apply_events([{"e": "night_start", "night": 2, "rent": 60}] as Array[Dictionary])


## Script cost (the room's _process) and wall time per frame with a busy scene (dread 0.9, customer, bubble, particles).
func _measure(cat: Catalog, picks: PackedStringArray) -> void:
	_room.set_dread(0.9 * Tuning.shared().wake_threshold)
	_room.setup(_run_with(cat, picks))
	_customer("seller", picks[0], "widow")
	_room._show_bubble()
	_room._fx_sys.emit("sparkle", Vector2(300.0, 200.0), 60)
	await _frames(10)
	var t0: int = Time.get_ticks_usec()
	for i: int in range(300):
		_room._process(1.0 / 60.0)
	var script_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 300.0
	var worst: float = 0.0
	var total: float = 0.0
	var samples: PackedFloat64Array = []
	var last: int = Time.get_ticks_usec()
	for i: int in range(120):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	samples.sort()
	for v: float in samples:
		total += v
		worst = maxf(worst, v)
	print("MS script_process=%.3f ms/frame  frame_wall avg=%.2f p95=%.2f max=%.2f (xvfb software GL)" % [script_ms, total / 120.0, samples[int(120 * 0.95)], worst])


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
	img.save_png(OUT_PATH)
	print("SHEET %s %dx%d" % [OUT_PATH, img.get_width(), img.get_height()])
	quit()
