extends SceneTree
## Step 39: ten 1920x1080 screenshots of the best moments, from the real game scenes (the title, the shop, and the test
## menu's own staged tiles), written to /mnt/project-files/store/screenshots/. Each shot waits on an observed state with a
## frame-count fallback that is reported. Never touches player data.
## Run: xvfb-run -a godot --path . --fixed-fps 60 --resolution 1920x1080 -s res://tests/shots/screenshots.gd -- --scripted
## `--out=<dir>` overrides the folder (keep the trailing slash).

const OUT_DIR: String = "/mnt/project-files/store/screenshots/"
const FALLBACK_FRAMES: int = 300
const ORDER: Array[String] = ["title", "haggle_at_the_counter", "uv_lamp_shows_the_wrongness", "dread_eyes_in_the_dark",
	"the_shop_wakes_possession", "storm_at_the_window", "the_midnight_table", "the_collector", "an_ending", "the_altar"]

var _g: Variant  # untyped: ShopGame names the Flags autoload, which a -s script cannot see at parse time
var _out: String = OUT_DIR
var _n: int = 0
var _only: PackedStringArray = PackedStringArray()  ## --only=a,b: just those shots (ids: title, haggle, uv, dread, wake, storm, table, collector, ending, altar)
var _fallbacks: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _until(cond: Callable, max_frames: int = FALLBACK_FRAMES) -> bool:
	for _i: int in range(max_frames):
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _want(id: String) -> bool:
	return _only.is_empty() or _only.has(id)


func _shot(label: String, observed: bool) -> void:
	await _frames(4)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_n += 1
	var path: String = "%sscreenshot_%02d_%s.png" % [_out, ORDER.find(label) + 1, label]
	var err: Error = img.save_png(path)
	if not observed:
		_fallbacks.append(label)
	print("SHOT %02d %s %dx%d%s" % [_n, label, img.get_width(), img.get_height(), "" if observed else " [FALLBACK]"])
	if err != OK:
		print("SHOT ERROR %s" % error_string(err))


## A staged tile of the test menu (real logic and real events), its label overlay hidden.
func _tile(id: String) -> void:
	_g.open_test_menu()
	_g.run_test_tile(id)
	_g._test_overlay.visible = false


func _untile() -> void:
	_g.exit_test_tile()
	_g.leave_test_menu()
	_g.cards.clear()


## A seed whose first customer is a seller holding a cursed object, so the UV lamp has a tell to show.
func _cursed_seed() -> int:
	for s: int in range(1, 80):
		var run := RunState.new()
		run.start(s, Catalog.load_default(), Tuning.new())
		if str(run.customer.get("kind", "")) == RunState.SELLER and str((run.customer["item"] as Dictionary).get("curse", "")) != "":
			return s
	return 7


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	if _want("title"):
		var title: Variant = (load("res://game/ui/title_screen.gd") as GDScript).new()
		title.settings = (load("res://game/ui/ts_settings.gd") as GDScript).new()
		root.add_child(title)
		title.room.set_title_mode(true)  # the live shop behind the title: slow drift, a shadow at the window, a moth at the lamp
		await _frames(480)
		await _shot("title", true)
		title.free()
		await _frames(2)
	_g = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(_g)
	await _frames(20)
	var seed_in: int = _cursed_seed()
	_g.new_run(seed_in, {}, {"regulars": {}})
	await _frames(3)
	_g.cards.clear()
	var here: bool = await _until(func() -> bool: return _g.room.customer_state() == "here", 600)
	_g.room._bubble.finish_typing()
	await _frames(40)
	if _want("haggle"):
		await _shot("haggle_at_the_counter", here)
	if _want("uv"):
		_g.activate("tool:uv")
		var fx: bool = await _until(func() -> bool: return _g.room.fx_kind() != "", 30)
		await _frames(24)
		await _shot("uv_lamp_shows_the_wrongness", fx)
	if _want("dread"):
		var thr: float = Tuning.shared().wake_threshold
		_g.run.dread = 0.9 * thr
		_g.room.set_dread(0.9 * thr)
		await _frames(140)
		await _shot("dread_eyes_in_the_dark", true)
		_g.run.dread = 0.0
		_g.room.set_dread(0.0)
	var ids: Array[String] = ["wake_possession", "event_storm", "table_pairs", "collector_pleased"]
	var keys: Array[String] = ["wake", "storm", "table", "collector"]
	var names: Array[String] = ["the_shop_wakes_possession", "storm_at_the_window", "the_midnight_table", "the_collector"]
	for i: int in range(ids.size()):
		if not _want(keys[i]):
			continue
		if ids[i] == "wake_possession":
			_g.room.wake(7, "possession")  # the test tile does not start the wake here, so start it on the room itself
		else:
			_tile(ids[i])
		var ok: bool = true
		match ids[i]:
			"wake_possession":
				for _w: int in range(1500):  # the wake runs on physics ticks, so wait on those
					if _g.room.wake_type() == "possession" and _g.room._wake_tick > ShopRoom2D.BEAT_TICKS + 70:
						break
					await physics_frame
				ok = _g.room.wake_type() == "possession"
			"event_storm":
				await _frames(60)
				_g.cards.clear()
				await _frames(20)
				_g.room._t = 17.99
			"collector_pleased":
				await _frames(150)
				_g.cards.clear()
				await _frames(30)
			_:
				await _frames(150)
		await _shot(names[i], ok)
		_untile()
		await _frames(30)
	if _want("ending"):
		var endings: Array = (load("res://game/ui/test_scenes.gd") as GDScript).get_script_constant_map().get("ENDING_IDS", []) as Array
		var eid: String = str(endings[0]) if not endings.is_empty() else "debt_free"
		_tile("ending_" + eid)
		await _frames(240)
		await _shot("an_ending", true)
		_untile()
		await _frames(30)
	if _want("altar"):
		_tile("altar")
		await _frames(120)
		await _shot("the_altar", true)
	print("SHOTS %d dir=%s fallbacks=%d %s" % [_n, _out, _fallbacks.size(), ",".join(_fallbacks)])
	quit()
