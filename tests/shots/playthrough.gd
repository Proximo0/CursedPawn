extends SceneTree
## A scripted playthrough of the real game: the omen draw, then the real ShopGame scene and its real RunState driven
## through a whole run with ShopBot-like decisions, every action sent through the UI's own entry points (activate,
## cast_spell, pick_held). One frame is saved per milestone, each keyed on an observed state (an event, a widget, a
## finished animation) with a frame-count fallback that is reported when it fires: the omen pick, the first tell, a
## cast, a request pinning and being filled, the Midnight Table with dice, Pairs, the wheel and the hand, the
## Collector's omen and arrival, the wake, the run end and the Altar. Cells are named for what was seen.
## xvfb-run -a godot --path . --fixed-fps 60 -s res://tests/shots/playthrough.gd -- --scripted
## Writes /tmp/shots/playthrough_sheet.png. Never touches player data.

const OUT_PATH: String = "/tmp/shots/playthrough_sheet.png"
const CELL := Vector2i(640, 360)
const LABEL_H: int = 16
const COLS: int = 3
const MAX_STEPS: int = 2500
const FALLBACK_FRAMES: int = 240

var _g: Variant  # untyped: ShopGame names the Flags autoload, which a -s script cannot see at parse time
var _cells: Array[Image] = []
var _names: Array[String] = []
var _done: Dictionary = {}  ## milestone id -> true
var _fallbacks: PackedStringArray = PackedStringArray()
var _bot: ShopBot


func _initialize() -> void:
	_go.call_deferred()


func _ue_offer(seed_in: int) -> Array[String]:
	var out: Array[String] = []
	out.assign((load("res://game/ui/ui_engage.gd") as GDScript).call("omen_offer", seed_in))
	return out


func _ue_opts(level: int, omen: String, daily: bool) -> Dictionary:
	return (load("res://game/ui/ui_engage.gd") as GDScript).call("make_opts", level, omen, daily)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


## Waits until cond is true; false when max_frames passed first (a fallback, noted for the report).
func _until(cond: Callable, max_frames: int = FALLBACK_FRAMES) -> bool:
	for _i: int in range(max_frames):
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _snap(label: String, observed: bool = true) -> void:
	await _frames(3)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	_cells.append(img)
	_names.append(label if observed else label + " [FALLBACK]")
	if not observed:
		_fallbacks.append(label)
	print("CELL %s" % _names[_names.size() - 1])


## Keeps only the queued card whose `key` equals `value`, moved to the front. False when none is queued.
func _keep_card(key: String, value: String) -> bool:
	for c: Dictionary in _g.cards:
		if str(c.get(key, "")) == value:
			_g.cards.assign([c])
			return true
	return false


func _once(id: String) -> bool:
	if _done.has(id):
		return false
	_done[id] = true
	return true


func _has_event(events: Array[Dictionary], name: String) -> Dictionary:
	for e: Dictionary in events:
		if str(e.get("e", "")) == name:
			return e
	return {}


## The next command of the playthrough policy: the cautious bot in the shop, and at the first Midnight Table a short
## script (Pairs, dice, wheel, hand) so every game shows. `st` carries the script's position. Pure on the run, so the
## seed search below can replay exactly what the live game will do.
func _decide(run: RunState, st: Dictionary) -> Dictionary:
	if run.phase != RunState.PHASE_TABLE:
		return _bot.decide(run)
	var tbl: Dictionary = run.table
	if int(st.get("tables", 0)) >= 1 or run.cash < 8:
		return {"t": "table_leave"}
	if not (tbl["pairs"] as Dictionary).is_empty():
		var i: int = int(st.get("pi", 0))
		st["pi"] = i + 1
		return {"t": "pairs_flip", "i": i % 10}
	if not (tbl["hand"] as Dictionary).is_empty():
		return {"t": "hand_stand"}
	st["pi"] = 0
	var order: Array[String] = ["table_pairs", "table_dice", "table_wheel", "table_hand"]
	var stage: int = int(st.get("stage", 0))
	if stage < order.size() and int(tbl["games_left"]) > 0:
		st["stage"] = stage + 1
		var cmd: Dictionary = {"t": order[stage], "stake": 2}
		if order[stage] == "table_dice":
			cmd["call"] = "high"
		return cmd
	return {"t": "table_leave"}


func _after_table_cmd(cmd: Dictionary, st: Dictionary) -> void:
	if str(cmd["t"]) == "table_leave":
		st["tables"] = int(st.get("tables", 0)) + 1
		st["stage"] = 0


## Plays the policy on a bare RunState and scores it: reached the Collector (and he was pleased), won, filled a request.
func _sim_score(seed_in: int, omen_index: int) -> int:
	var omens: Array[String] = _ue_offer(seed_in)
	if omens.size() <= omen_index:
		return -1
	var run := RunState.new()
	var sim_opts: Dictionary = _ue_opts(0, omens[omen_index], false)
	sim_opts["regulars"] = {}  # regular visits on, as for a real profile
	run.start(seed_in, Catalog.load_default(), Tuning.new(), {}, sim_opts)
	var st: Dictionary = {}
	var score: int = 0
	var n: int = 0
	while not run.is_over() and n < 3000:
		var cmd: Dictionary = _decide(run, st)
		var ev: Array[Dictionary] = run.apply(cmd)
		n += 1
		if run.phase == RunState.PHASE_TABLE or str(cmd["t"]) == "table_leave":
			_after_table_cmd(cmd, st)
		for e: Dictionary in ev:
			match str(e["e"]):
				"collector_arrives":
					score += 100
				"collector_pleased":
					score += 50
				"request_done":
					score += 20
				"regular":
					score += 40
				"cast":
					score += 5
	if run.won:
		score += 30
	return score


func _find_seed() -> Vector2i:
	var best := Vector2i(3, 1)
	var best_score: int = -1
	for s: int in range(1, 61):
		for oi: int in range(3):
			var sc: int = _sim_score(s, oi)
			if sc > best_score:
				best_score = sc
				best = Vector2i(s, oi)
		if best_score >= 200:
			break
	print("PLAYTHROUGH seed %d omen %d score %d" % [best.x, best.y, best_score])
	return best


# ---------------------------------------------------------------- the guided first night

## Starts the tutorial run (real when the logic's Tutorial exists, else a plain run with a synthetic hint) and snaps the
## overlay: everything dimmed but the lit element, the quill and the ink-written note.
func _tutorial() -> void:
	var real: bool = ResourceLoader.exists("res://game/logic/tutorial.gd")
	var seed_in: int = 7
	if real:
		seed_in = int((load("res://game/logic/tutorial.gd") as GDScript).get_script_constant_map().get("SEED", 7))
	_g.new_run(seed_in, {}, {"tutorial": true})
	await _frames(3)
	var live: bool = await _until(func() -> bool: return _g.hud.tutorial.active, 30)
	if not live:
		_g.hud.feed([{"e": "tutorial_step", "step": 1, "text": "Use the lamp, the scale, your ears, your hands. Look before you buy.", "focus": "tools"}] as Array[Dictionary])
	_g.cards.clear()
	await _until(func() -> bool: return _g.hud.tutorial.age > 1.4, 120)
	_g.room.settle_visuals()
	await _snap("tutorial: the tools lit, the rest dimmed, quill and ink note%s" % ("" if live else " (synthetic hint)"), live)
	if live:
		var first: int = int(_g.hud.tutorial.step)
		for _i: int in range(6):  # do what the hints ask until the step changes, so a second hint shows
			var cmd: Dictionary = _bot.decide(_g.run)
			_drive_customer(cmd)
			_g.cards.clear()
			await _frames(4)
			if int(_g.hud.tutorial.step) != first and _g.hud.tutorial.active:
				break
		await _until(func() -> bool: return _g.hud.tutorial.age > 1.4, 120)
		_g.cards.clear()
		await _snap("tutorial: the next step points at %s" % str(_g.hud.tutorial.focus), _g.hud.tutorial.active)
	_g.hud.tutorial.clear()


# ---------------------------------------------------------------- the run

func _go() -> void:
	_bot = ShopBot.new(ShopBot.CAUTIOUS)
	_g = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(_g)
	await _frames(20)
	var pick: Vector2i = _find_seed()
	await _tutorial()
	await _omen_draw(pick.x, pick.y)
	await _frames(2)
	await _play()
	await _altar()
	_save_sheet()


## The setup screen for the seed: cards deal in, one is looked at and turns up, Enter flips before it picks.
func _omen_draw(seed_in: int, omen_index: int) -> void:
	var s: Variant = (load("res://game/ui/ui_run_setup.gd") as GDScript).new()
	s.settings = (load("res://game/ui/ts_settings.gd") as GDScript).new()
	s.omen_ids = _ue_offer(seed_in)
	var picked_opts: Array[Dictionary] = []
	s.chosen.connect(func(o: Dictionary) -> void: picked_opts.append(o))
	root.add_child(s)
	await _frames(3)
	var ok: bool = await _until(func() -> bool: return s.canvas.t - s._stage_t > 1.3)
	s.focus_id = "card%d" % omen_index
	var ok2: bool = await _until(func() -> bool: return s.turned_up(omen_index))
	await _snap("omen draw: card 1 turned up, art and upside/downside", ok and ok2)
	var other: int = 2 if omen_index != 2 else 1  # a card not yet looked at (card 0 turns up on its own)
	s.focus_id = "card%d" % other
	await _frames(3)
	s.ts_key(KEY_ENTER)  # the first Enter flips an unseen card, it must not pick it
	var flipped_first: bool = await _until(func() -> bool: return s.turned_up(other))
	if s.picked != -2:
		_fallbacks.append("BUG: Enter picked before it flipped")
	await _snap("omen draw: Enter flipped a card first, none picked yet", flipped_first and s.picked == -2)
	s.focus_id = "card%d" % omen_index
	await _until(func() -> bool: return s.turned_up(omen_index), 120)
	s.ts_key(KEY_ENTER)
	await _until(func() -> bool: return not picked_opts.is_empty(), 200)
	var opts: Dictionary = picked_opts[0] if not picked_opts.is_empty() else _ue_opts(0, "", false)
	opts["regulars"] = {}
	await _snap("omen picked: the others dim, the card lifts", not picked_opts.is_empty())
	s.free()
	await _frames(2)
	_g.new_run(seed_in, {}, opts)
	await _frames(2)


func _play() -> void:
	await _until(func() -> bool: return not _g.cards.is_empty(), 20)
	if not _g.cards.is_empty():
		_g.cards[0]["age"] = 0.9
	await _snap("night 1 card landing, real events", not _g.cards.is_empty())
	_g.cards.clear()
	var st: Dictionary = {}
	var steps: int = 0
	while not _g.run.is_over() and steps < MAX_STEPS:
		steps += 1
		if not (_g.run.phase == RunState.PHASE_TABLE and not _done.has("table_open")):
			_g.cards.clear()  # the first table's cards are kept for its milestone
		_g.hud.found.popups.clear()
		var r: RunState = _g.run
		var cmd: Dictionary = _decide(r, st)
		var night_before: int = r.night
		var was_table: bool = r.phase == RunState.PHASE_TABLE
		if was_table:
			await _table_cmd(cmd)
			_after_table_cmd(cmd, st)
		else:
			_drive_customer(cmd)
		await _after_action(night_before)
	for c: Dictionary in _g.cards:
		c["age"] = 0.0
	_g.cards.clear()
	var shown: bool = await _until(func() -> bool: return _g.end_panel_visible() and _g.hud._end_t > 1.6, 400)
	await _snap("run end: %s, ectoplasm earned" % ("survived" if _g.run.won else "lost"), shown)
	await _synthetic_round6()


## Whatever of the round-6 pop-ups the real run did not produce (the logic may not have landed, or the policy never met
## a regular) is shown from synthetic events, and the cell says so.
func _synthetic_round6() -> void:
	_g.hud.toasts.clear()
	if not _done.has("regular"):
		_g.hud.toasts.feed([{"e": "regular", "id": "widow", "name": "The Widow March", "chapter": 1,
			"line": "It came home again. I only wanted it quiet."}] as Array[Dictionary])
		await _until(func() -> bool: return float(_g.hud.toasts.regulars[0]["age"]) > 1.6 if not _g.hud.toasts.regulars.is_empty() else true, 200)
		await _snap("a regular arrives: portrait card (synthetic event)", false)
		_g.hud.toasts.clear()
	if not _done.has("deed"):
		_g.hud.toasts.push_deed("first_light")
		await _until(func() -> bool: return float(_g.hud.toasts.deeds[0]["age"]) > 1.8 if not _g.hud.toasts.deeds.is_empty() else true, 200)
		await _snap("deed toast: seal stamped, name inked (synthetic)", false)
		_g.hud.toasts.clear()


## One bot action through the UI's own entry points.
func _drive_customer(cmd: Dictionary) -> void:
	match str(cmd.get("t", "pass")):
		"inspect":
			_g.activate("tool:%s" % str(cmd["tool"]))
		"offer":
			_g.offer_amount = int(cmd["amount"])
			_g.activate("offer")
		"buy":
			_g.activate("buy")
		"sell":
			_g.activate("item:%d" % int(cmd["uid"]))
			_g.activate("item:%d" % int(cmd["uid"]))  # a second click sells
		"cast":
			_g.cast_spell(str(cmd["spell"]))
			if _g.hud.spell_bar.pending_item_spell != "":
				_g.pick_held(int(cmd.get("uid", -1)))
		_:
			_g.activate("pass")


## Looks at the events the last action produced and snaps a cell for each new kind of milestone.
func _after_action(night_before: int) -> void:
	var ev: Array[Dictionary] = []
	ev.assign(_g.run.last_events)
	_g.hud.found.popups.clear()  # a find popup would cover the milestone being shown
	var insp: Dictionary = _has_event(ev, "inspected")
	if not insp.is_empty() and str(insp.get("tell", "")) != "" and _once("tell"):
		_g.cards.clear()
		_g.room.settle_visuals()
		_g.log_age[_g.log_age.size() - 1] = 9.0
		await _frames(4)
		await _snap("seller: a %s tell on a pinned note" % str(insp["tool"]), not _g.tell_texts.is_empty())
	var cst: Dictionary = _has_event(ev, "cast")
	if not cst.is_empty() and bool(cst.get("ok", true)) and _once("cast"):
		await _frames(12)
		await _snap("cast %s: slot flash, spark, ledger line" % str(cst.get("spell", "")), _g.hud.spell_bar.flashing(str(cst.get("spell", ""))))
	var req: Dictionary = _has_event(ev, "request_new")
	if not req.is_empty() and _once("req_new"):
		_g.cards.clear()
		var ok: bool = await _until(func() -> bool: return not _g.hud.requests.notes.is_empty() and float(_g.hud.requests.notes[0]["age"]) > 0.5)
		_g.room.settle_visuals()
		await _snap("request pinned: %s" % str(req.get("line", "")).left(40), ok)
	if not _has_event(ev, "request_done").is_empty() and _once("req_done"):
		await _frames(18)
		await _snap("request filled: DONE stamp slams down", true)
	if not _has_event(ev, "request_failed").is_empty() and _once("req_failed"):
		await _frames(24)
		await _snap("request failed: the note tears", true)
	var om: Dictionary = _has_event(ev, "collector_omen")
	if not om.is_empty() and _once("c_omen"):
		var ok2: bool = await _until(func() -> bool: return _g.hud.requests._find("collector").size() > 0 and float(_g.hud.requests._find("collector")["age"]) > 0.5)
		_g.cards.clear()
		await _snap("night 3: the Collector's want on the board", ok2)
	var ar: Dictionary = _has_event(ev, "collector_arrives")
	if not ar.is_empty() and _once("c_arrives"):
		var ok3: bool = _keep_card("style", "collector")
		if ok3:
			_g.cards[0]["age"] = 3.2
		await _snap("THE COLLECTOR arrives: DISPLAY name bleeding in", ok3)
		_g.cards.clear()
	if not _has_event(ev, "collector_pleased").is_empty() and _once("c_pleased"):
		await _frames(30)
		await _snap("the Collector is pleased", true)
	if not _has_event(ev, "collector_refused").is_empty() and _once("c_refused"):
		await _frames(30)
		await _snap("the Collector refused: curse and toll", true)
	if _g.run.night == 5 and night_before != 5 and not _done.has("c_arrives") and _once("night5"):
		await _frames(30)
		await _snap("night 5 begins (no Collector events seen)", false)
	if not _has_event(ev, "wake").is_empty() and _once("wake"):
		var ok4: bool = await _until(func() -> bool: return not _g.cards.is_empty(), 20)
		if not _g.cards.is_empty():
			_g.cards[0]["age"] = 1.4
		await _snap("SOMETHING WOKE card", ok4)
	var reg: Dictionary = _has_event(ev, "regular")
	if not reg.is_empty() and _once("regular"):
		_g.cards.clear()
		var ok5: bool = await _until(func() -> bool: return not _g.hud.toasts.regulars.is_empty() and float(_g.hud.toasts.regulars[0]["age"]) > 1.6)
		await _snap("a regular arrives: %s, portrait card" % str(reg.get("name", "?")), ok5)
	for rk: String in ["regular_done", "regular_refused"]:
		if not _has_event(ev, rk).is_empty() and _once(rk):
			await _frames(20)
			await _snap("%s: the ledger line" % rk, true)
	if not _g.hud.toasts.deeds.is_empty() and _once("deed"):
		_g.cards.clear()
		var ok6: bool = await _until(func() -> bool: return not _g.hud.toasts.deeds.is_empty() and float(_g.hud.toasts.deeds[0]["age"]) > 1.8)
		await _snap("deed toast: seal stamped, name inked", ok6)
	if _g.run.customer.get("kind", "") == RunState.BUYER and not _g.run.sellable().is_empty() and _once("buyer"):
		_g.cards.clear()
		_g.room.settle_visuals()
		await _frames(30)
		await _snap("buyer: glowing items on the shelf", true)


# ---------------------------------------------------------------- the Midnight Table

func _table_cmd(cmd: Dictionary) -> void:
	var tb: Variant = _g.hud.table
	var t: String = str(cmd["t"])
	if _once("table_open"):
		var found_card: bool = _keep_card("title", "THE MIDNIGHT TABLE")
		if found_card:
			_g.cards[0]["age"] = 0.9
		await _snap("the Midnight Table opens", found_card)
		_g.cards.clear()
		await _frames(20)
	if cmd.has("stake"):
		tb.stake = int(cmd["stake"])
	match t:
		"table_pairs":
			_g.activate("t_pairs")
			await _frames(24)
		"pairs_flip":
			_g.activate("pair:%d" % int(cmd["i"]))
			await _frames(16)
			if _has_event(_g.run.last_events, "pairs_match").size() > 0 and _once("pairs_match"):
				await _frames(14)
				await _snap("table: Pairs, a match glowing and floating up", true)
			elif int(cmd["i"]) == 3 and _once("pairs_mid"):
				await _snap("table: Pairs mid-game, cards up and down", tb.pairs_active)
		"table_dice":
			_g.activate("t_dice_high")
			var ok: bool = await _until(func() -> bool: return not tb.banner.is_empty(), 200)
			await _frames(25)
			await _snap("table: dice result, coins flying, bar and table cash in sync", ok)
			await _until(func() -> bool: return not tb.busy(), 200)
		"table_wheel":
			_g.activate("t_wheel")
			await _frames(70)
			await _snap("table: the wheel spinning down", tb.wheel_angle != 0.0)
			await _until(func() -> bool: return not tb.busy(), 400)
		"table_hand":
			_g.activate("t_hand")
			await _frames(70)
			await _snap("table: the hand, cards flipping in", tb.hand_active)
		"hand_stand":
			_g.activate("t_stand")
			await _frames(50)
			await _until(func() -> bool: return not tb.hand_active and not tb.busy(), 300)
		_:
			await _until(func() -> bool: return not tb.busy(), 300)
			_g.activate("t_leave")
			await _frames(3)


# ---------------------------------------------------------------- the altar

## The Ledger book: deeds (some earned, secrets as ????) and the regulars page.
func _ledger() -> void:
	var ul: GDScript = load("res://game/ui/ui_ledger.gd") as GDScript
	var real: bool = not (ul.call("deed_defs") as Array).is_empty() and not (ul.call("regular_defs") as Array).is_empty()
	if not real:
		ul.set("force_deeds", _sample_deeds())
		ul.set("force_regulars", _sample_regulars())
	var d: Array = ul.call("deed_defs")
	var rg: Array = ul.call("regular_defs")
	var prof := Node.new()  # a stand-in profile with the two fields the Ledger reads
	prof.set_script(_profile_stub())
	var got := PackedStringArray()
	for i: int in range(0, d.size(), 3):
		got.append(str((d[i] as Dictionary)["id"]))
	prof.set("deeds", got)
	var prog: Dictionary = {}
	for i: int in range(rg.size()):
		prog[str((rg[i] as Dictionary)["id"])] = [2, 1, 0, 3, 1, 0][i % 6]
	prof.set("regulars", prog)
	var p: Variant = (load("res://game/ui/pause_menu.gd") as GDScript).new()
	p.settings = (load("res://game/ui/ts_settings.gd") as GDScript).new()
	p.pauses_tree = false
	p.profile = prof
	root.add_child(p)
	p.open()
	await _frames(3)
	p.ts_activate_menu("ledger")
	await _until(func() -> bool: return p.ledger.age > 1.6, 200)
	await _snap("ledger of deeds: inked seals, secrets as ????%s" % ("" if real else " (sample data)"), real)
	p.ledger.activate("ledger_tab_regulars")
	await _until(func() -> bool: return p.ledger.age > 1.4, 200)
	await _snap("ledger: the regulars, arcs so far%s" % ("" if real else " (sample data)"), real)
	p.free()
	prof.free()
	await _frames(2)


func _profile_stub() -> GDScript:
	var sc := GDScript.new()
	sc.source_code = "extends Node\nvar deeds: PackedStringArray = PackedStringArray()\nvar regulars: Dictionary = {}\n"
	sc.reload()
	return sc


func _sample_deeds() -> Array:
	var out: Array = []
	var names: Array[String] = ["First Light", "Dawn Again", "The Quiet Hand", "Candle Counter", "Rent Day", "Cold Cash", "Pen Pal",
		"Perfect Pairs", "Table Shark", "Bad Luck Charm", "The Hush", "Full House", "Seal Breaker", "Ghost Friend"]
	for i: int in range(names.size()):
		out.append({"id": names[i].to_lower().replace(" ", "_"), "name": names[i], "text": "Do the thing the deed asks, once, and live.",
			"secret": i % 4 == 2})
	return out


func _sample_regulars() -> Array:
	var names: Array[String] = ["The Widow March", "Little Tom", "Father Aldous", "The Great Mirelli", "Mrs Quill", "Mr Hollow"]
	var out: Array = []
	for i: int in range(names.size()):
		out.append({"id": names[i].to_lower().replace(" ", "_"), "name": names[i], "tid": "x", "chapters": [
			{"line": "It came home again. I only wanted it quiet."}, {"line": "Take it, please. It hums at night."},
			{"line": "Keep it. We are friends now."}, {"line": "Goodbye."}]})
	return out


func _altar() -> void:
	root.remove_child(_g)  # the title and the altar are drawn on their own
	await _frames(2)
	var t: Variant = (load("res://game/ui/title_screen.gd") as GDScript).new()
	t.settings = (load("res://game/ui/ts_settings.gd") as GDScript).new()
	t.altar_on = true
	t.altar_ecto = 14
	t.tutorial_on = true
	root.add_child(t)
	await _frames(3)
	t.canvas.t = 12.0
	await _snap("title with SKIP TUTORIAL, THE ALTAR, LEDGER and ectoplasm to spend", true)
	t.free()
	await _frames(2)
	await _ledger()
	var ua: GDScript = load("res://game/ui/ui_altar.gd") as GDScript
	var real: bool = bool(ua.call("available"))
	if (ua.call("defs") as Array).is_empty():
		ua.set("force_defs", ua.get_script_constant_map()["FALLBACK_DEFS"])
	var a: Variant = ua.new()
	a.settings = (load("res://game/ui/ts_settings.gd") as GDScript).new()
	a.ecto = 14
	var defs: Array = ua.call("defs")
	var pick_id: String = str((defs[2] as Dictionary)["id"])
	a.ranks = {str((defs[0] as Dictionary)["id"]): 1, str((defs[1] as Dictionary)["id"]): 2}
	a.buy_fn = func(_id: String) -> String: return "ok"
	root.add_child(a)
	await _frames(3)
	var ok: bool = await _until(func() -> bool: return a._intro_t > 1.6, 200)
	a.focus_id = "up:%s" % pick_id
	await _snap("altar: candles, ectoplasm 14, upgrade cards with rank pips%s" % ("" if real else " (sample data)"), ok)
	a.ts_activate("up:%s" % pick_id)
	await _frames(5)
	await _snap("altar buy at 1x: the card flashes white, wisps rise", a.ranks.get(pick_id, 0) == 1)
	await _frames(22)
	await _snap("altar buy: big wisps with trails fly in, the pip ignites", a.ranks.get(pick_id, 0) == 1)
	a.free()


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
	print("SHEET %s %dx%d cells=%d" % [OUT_PATH, img.get_width(), img.get_height(), _cells.size()])
	for f: String in _fallbacks:
		print("FALLBACK %s" % f)
	quit()
