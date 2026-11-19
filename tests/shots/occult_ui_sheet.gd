extends SceneTree
## Contact sheet of the occult round's UI, driven by hand-built event dictionaries (no logic needed): the spell bar with
## a hover tip and a cast flash, the Banish item picker, the found whisper, the page and curio reveal popups, the
## Midnight Table (idle, dice tumbling, hand cards flipping, the wheel mid-spin, Tarot Pairs mid-game), the grimoire
## and the run-end finds list. Time is stepped by hand so the sheet repeats.
## xvfb-run -a godot --path . -s res://tests/shots/occult_ui_sheet.gd -- --scripted
## Writes /tmp/shots/occult_ui_sheet.png. Never touches player data.

const OUT_PATH: String = "/tmp/shots/occult_ui_sheet.png"
const CELL := Vector2i(480, 270)
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
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	_cells.append(img)
	_names.append(label)
	print("CELL %s" % label)


func _step(secs: float) -> void:
	var run: RunState = _game.run
	var n: int = int(ceil(secs / 0.05))
	for _i: int in range(n):
		_game.hud.table.tick(0.05, run)
		_game.hud.found.tick(0.05)
		_game.hud.spell_bar.tick(0.05)


func _evs(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in list:
		out.append(e as Dictionary)
	return out


func _feed(list: Array) -> void:
	_game.hud.feed(_evs(list))


func _go() -> void:
	_game = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await _frames(20)
	var occ: GDScript = load("res://game/ui/ui_occult.gd") as GDScript
	occ.set("force_known", PackedStringArray(["scry", "hex", "banish", "seal"]))
	_game.new_run(3)
	_game.cards.clear()
	_game.room.settle_visuals()
	_game.hints.dismiss()
	_game.hud.set_process(false)
	var hud: Variant = _game.hud
	# 1: the bar, a hover tip, a cast flash and the whisper
	_game.hover_id = "spell:hex"
	_feed([{"e": "cast", "spell": "scry", "ok": true, "backfire": false, "text": "x", "dread": 0.5}, {"e": "found_hint", "kind": "page"}])
	_step(0.2)
	await _snap("spell bar: hover tip, cast flash, whisper")
	# 2: banish asks for a held item
	_game.hover_id = ""
	hud.spell_bar.pending_item_spell = "banish"
	_game.run.inventory.append({"uid": 91, "id": "music_box", "name": "Music box", "category": "toy", "value": 40})
	_game.run.inventory.append({"uid": 92, "id": "violin", "name": "Violin", "category": "instrument", "value": 60})
	_game.hover_id = "pick:92"
	await _snap("banish: pick a held item")
	hud.spell_bar.pending_item_spell = ""
	_game.hover_id = ""
	# 3, 4: found popups
	_feed([{"e": "found", "kind": "page", "id": "banish", "name": "Banish"}])
	_step(0.55)
	await _snap("found: a torn spell page flutters in")
	_step(4.0)
	_feed([{"e": "found", "kind": "curio", "id": "curio_10", "name": "The Bone Candle"}])
	_step(1.6)
	await _snap("found: a curio glints in")
	_step(4.0)
	# the Midnight Table
	_game.run.phase = "table"
	_game.run.cash = 48
	_feed([{"e": "table_open", "night": 2, "games_left": 3, "lots_left": 1}])
	_game.cards.clear()
	_step(0.5)
	hud.table.shown_cash = 48
	await _snap("table: idle felt, croupier, controls")
	_feed([{"e": "dice", "d1": 4, "d2": 6, "call": "high", "win": true, "stake": 6, "payout": 12}])
	_step(0.5)
	await _snap("table: dice tumbling")
	_step(2.0)
	_feed([{"e": "hand_card", "who": "you", "card": 6, "total": 6}, {"e": "hand_card", "who": "you", "card": 5, "total": 11},
		{"e": "hand_card", "who": "house", "card": 8, "total": 8}])
	_step(1.0)
	await _snap("table: hand cards flipping in")
	_feed([{"e": "hand_end", "you": 11, "house": 15, "win": false, "stake": 6, "payout": 0}])
	_step(2.2)
	await _snap("table: a loss smokes away")
	var segs: Array[Dictionary] = occ.call("wheel_segments")
	_feed([{"e": "wheel", "segment": 4, "name": str(segs[4]["name"]), "mult": 0.0, "stake": 6, "payout": 0, "prize": "page", "dread": 0.2}])
	_step(1.4)
	await _snap("table: the wheel spins")
	_step(3.0)
	_feed([{"e": "pairs_deal", "count": 10, "tries": 5}])
	_step(0.3)
	_feed([{"e": "pairs_flip", "i": 0, "card": "the_sun", "name": "The Sun"}, {"e": "pairs_flip", "i": 6, "card": "the_sun", "name": "The Sun"}])
	_step(0.4)
	_feed([{"e": "pairs_match", "card": "the_sun", "name": "The Sun", "mult": 1.5, "dread": 0.0}])
	_step(0.9)
	_feed([{"e": "pairs_flip", "i": 2, "card": "death", "name": "Death"}, {"e": "pairs_flip", "i": 3, "card": "the_fool", "name": "The Fool"}])
	_step(0.3)
	_feed([{"e": "pairs_flip", "i": 8, "card": "the_tower", "name": "The Tower"}])
	_step(0.18)
	_feed([{"e": "pairs_miss", "a": 2, "b": 3}])
	_step(0.42)
	_game.hover_id = "pair:9"
	await _snap("tarot pairs: a match floats, a miss shudders")
	_game.hover_id = ""
	_feed([{"e": "pairs_end", "matches": 1, "stake": 6, "payout": 9, "dread": 0.0}])
	_game.run.phase = RunState.PHASE_CUSTOMER
	_game.hud.table.reset_stage()
	# the grimoire
	var pm: Variant = _game.pause
	pm.known = PackedStringArray(["scry", "hex", "banish"])
	pm.open()
	pm.ts_activate_menu("grimoire")
	await _frames(2)
	pm._grim_t = 2.0
	await _snap("grimoire: known and greyed-out spells")
	pm.close()
	# run end with finds
	_game.run.inventory.clear()
	occ.set("force_found", [{"kind": "page", "id": "banish"}, {"kind": "curio", "id": "curio_10", "name": "The Bone Candle"},
		{"kind": "curio", "id": "curio_04", "name": "Placeholder"}])
	_game.run.phase = RunState.PHASE_OVER
	_game.run.won = true
	_game.cards.clear()
	await _snap("run end: found this run")
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
