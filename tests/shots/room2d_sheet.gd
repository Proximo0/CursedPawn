extends SceneTree
## Contact sheet of the 2D shop room: calm, props, the four tools, a card, three customers, Dread, and the wake.
## Run: xvfb-run -a godot --path . --resolution 1280x720 -s res://tests/shots/room2d_sheet.gd -- --scripted
## Writes /tmp/shots/room2d_sheet.png and prints the mean luminance of each cell. Never touches player data.

const OUT_PATH: String = "/tmp/shots/room2d_sheet.png"
const CELL := Vector2i(480, 270)
const LABEL_H: int = 16
const COLS: int = 4

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
	var seller: String = picks[0]
	_customer("seller", seller, "widow")
	await _snap("customer: widow + bubble")
	for tool: String in ["uv", "scale", "listen", "touch"]:
		_room.apply_events([{"e": "inspected", "tool": tool, "tell": "", "estimate": {}}] as Array[Dictionary])
		_room._fx_t = 0.5
		await _frames(1)
		_room._fx_t = 0.5
		await _snap("tool: " + tool)
	_room.apply_events([{"e": "wager", "card": "The Fool", "stake": 5, "payout": 10, "dread": 1.0}] as Array[Dictionary])
	_room._card_t = 0.62
	await _snap("card flip")
	_customer("buyer", "", "priest")
	await _snap("customer: priest (tall)")
	_customer("buyer", "", "haggler")
	await _snap("customer: haggler (short)")
	_room.set_dread(Tuning.shared().wake_threshold * 1.2)
	await _snap("dread high")
	_room.set_dread(0.0)
	_room.setup(_run_with(cat, picks))
	_room.wake(7)
	for target: int in [30, 90, 180]:
		while _room._wake_tick < target and _room.is_waking():
			await physics_frame
		await _snap("wake %.1f s" % (float(target) / 60.0))
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
	img.save_png(OUT_PATH)
	print("SHEET %s %dx%d" % [OUT_PATH, img.get_width(), img.get_height()])
	quit()
