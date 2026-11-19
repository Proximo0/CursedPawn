extends SceneTree
## Step 38: renders the Steam store images from the game's own art plus the DISPLAY font into /mnt/project-files/store/.
## Ready for upload, never uploaded. Run: xvfb-run -a godot --path . --resolution 1920x1080 -s res://tests/shots/store_art.gd -- --scripted
## The out dir can be overridden with `--out=<dir>` (the default is the project's store folder; keep the trailing slash).

const OUT_DIR: String = "/mnt/project-files/store/"

var _room: ShopRoom2D


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _grab() -> Image:
	await _frames(3)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run_with(cat: Catalog, ids: PackedStringArray) -> RunState:
	var run := RunState.new()
	run.start(11, cat, Tuning.new())
	run.inventory.clear()
	var uid: int = 100
	for o: Dictionary in cat.objects:
		if ids.has(str(o["id"])):
			run.inventory.append({"uid": uid, "id": o["id"], "name": o["name"], "category": o["category"], "value": o["value"],
				"curse": "", "est": 30, "tells": 0})
			uid += 1
	return run


func _go() -> void:
	var out_dir: String = OUT_DIR
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var cat: Catalog = Catalog.load_default()
	_room = ShopRoom2D.new()
	root.add_child(_room)
	await _frames(20)
	var ids: PackedStringArray = ["music_box", "silver_locket", "violin", "ledger", "candlestick", "porcelain_doll", "hand_mirror",
		"pocket_watch", "brass_key", "oil_portrait", "taxidermy_owl", "snow_globe", "lantern", "death_mask", "wax_seal", "kaleidoscope"]
	var shots: Dictionary = {}
	_room.setup(_run_with(cat, ids))
	_room.apply_events([{"e": "customer", "kind": "seller", "name": "Hand mirror", "category": "relic", "ask": 40, "tid": "widow", "line": ""}] as Array[Dictionary])
	_room.settle_visuals()
	_room._bubble.hide_now()
	await _frames(200)
	shots["room"] = await _grab()
	_room.setup(_run_with(cat, ids))
	_room.set_dread(0.9 * Tuning.shared().wake_threshold)
	_room.apply_events([{"e": "customer", "kind": "seller", "name": "Hand mirror", "category": "relic", "ask": 40, "tid": "medium", "line": ""}] as Array[Dictionary])
	_room.settle_visuals()
	_room._bubble.hide_now()
	await _frames(120)
	shots["dread"] = await _grab()
	_room.set_dread(0.0)
	_room.setup(_run_with(cat, ids))
	_room.apply_events([{"e": "customer", "kind": "buyer", "category": "toy", "tid": "collector", "boss": true}] as Array[Dictionary])
	_room.settle_visuals()
	_room._bubble.hide_now()
	await _frames(240)
	shots["collector"] = await _grab()
	shots["tableau"] = EndingArt.tableau_image("cursed")
	var look: Dictionary = {"id": "widow", "cloak": "#4b2a78", "eyes": "#ffd27a"}
	for row: Variant in (JSON.parse_string(FileAccess.open("res://game/data/customers.json", FileAccess.READ).get_as_text()) as Array):
		if str((row as Dictionary).get("id", "")) == "collector":
			look = row as Dictionary
	var figure: Image = SpriteKit.customer_texture(look).get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Dictionary = {"header": "capsule_header_920x430", "small": "capsule_small_462x174", "main": "capsule_main_1232x706",
		"vertical": "capsule_vertical_748x896", "library": "library_capsule_600x900", "hero": "library_hero_3840x1240",
		"logo": "library_logo_1280x720"}
	var ok: int = 0
	for kind: String in StoreArt.SIZES:
		var img: Image = StoreArt.compose(kind, shots, figure)
		var err: Error = img.save_png(out_dir + str(names[kind]) + ".png")
		if err == OK:
			ok += 1
		else:
			print("STORE ERROR %s %s" % [kind, error_string(err)])
	print("STORE ART files=%d dir=%s" % [ok, out_dir])
	quit()
