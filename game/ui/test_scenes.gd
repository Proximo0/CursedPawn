class_name TestScenes
extends RefCounted
## The tiles of the test menu and the code that sets each one up. Every tile builds a seeded state inside a ShopGame
## (a throwaway profile, nothing saved) and leaves it playable. Content that has not landed yet still has its tile:
## the events it would carry are fed to the room, which ignores what it does not know.
## New scenes add a line to `tiles()` and a branch to `build()`; `test_ui_test_menu` opens every tile.

const GROUPS: Array[String] = ["START", "SPELLS", "BACKFIRES", "TABLE", "PEOPLE", "WAKES", "DREAD", "NIGHTS", "ENDINGS", "BOOKS", "POPUPS", "CURSES", "MUSIC"]
const SPELL_IDS: Array[String] = ["scry", "hex", "glamour", "banish", "summon", "seal"]
const WAKE_TYPES: Array[String] = ["drift", "topple", "lights_out", "door_lock", "possession"]
const EVENT_IDS: Array[String] = ["blackout", "storm", "auction", "full_moon"]
const ENDING_IDS: Array[String] = ["debt_free", "cursed_shop", "collector", "regulars"]
const REGULAR_IDS: Array[String] = ["march", "ned", "crowe", "vane", "ashby", "dottie"]
const EVENTS_PATH: String = "res://game/data/night_events.json"
const SEED: int = 4242
const NOTES: Dictionary = {
	"tutorial": "THE GUIDED FIRST NIGHT. FOLLOW THE NOTES.",
	"omen_draw": "DRAW AN OMEN CARD, PICK A HAUNTING, START.",
	"hand": "DRAW OR STAND AT THE TABLE.",
	"pairs": "FLIP TWO CARDS AT A TIME.",
	"request": "THE REQUESTER HAS COME FOR THEIR ORDER. SELL THEM IT.",
	"regular": "THEIR CHAPTER IS SET BY THE CHAPTER BUTTON IN THE MENU.",
	"collector_pleased": "WATCH HIM ARRIVE. THE SALE FOLLOWS.",
	"collector_refused": "WATCH HIM ARRIVE. THE REFUSAL FOLLOWS.",
	"dread": "LEFT AND RIGHT, OR CLICK THE BAR, MOVE DREAD.",
	"altar": "999 ECTOPLASM TO SPEND. NOTHING IS SAVED.",
	"journal": "EVERY PAGE UNLOCKED.",
	"found_page": "A TORN SPELL PAGE.",
	"found_curio": "A CURIO FROM THE BACK OF A DRAWER.",
	"deed_toast": "A DEED SEAL STAMPS DOWN.",
	"run_won": "THE RUN-END SCREEN, WON.",
	"run_lost": "THE RUN-END SCREEN, LOST.",
}


## Every tile: {id, group, label}.
const NEW_CURSES: PackedStringArray = ["costume_change", "copycat", "bashful_purse", "landlord_lullaby"]
const MUSIC_TRACKS: PackedStringArray = ["title", "shop", "table", "collector"]


static func tiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add(out, "START", "tutorial", "TUTORIAL NIGHT")
	_add(out, "START", "omen_draw", "OMEN DRAW")
	for s: String in SPELL_IDS:
		_add(out, "SPELLS", "spell_" + s, "CAST " + s.to_upper())
	for k: String in Grimoire.BACKFIRE_KINDS:
		_add(out, "BACKFIRES", "backfire_" + k, k.replace("_", " ").to_upper())
	_add(out, "TABLE", "table_dice", "DICE")
	_add(out, "TABLE", "table_hand", "HAND")
	_add(out, "TABLE", "table_wheel", "WHEEL")
	_add(out, "TABLE", "table_pairs", "TAROT PAIRS")
	_add(out, "TABLE", "table_item", "ITEM STAKE")
	_add(out, "TABLE", "table_lot", "SEALED LOT")
	_add(out, "PEOPLE", "request", "REQUEST FILLED")
	_add(out, "PEOPLE", "regular", "A REGULAR")
	_add(out, "PEOPLE", "haggle_nervous", "HAGGLE: NERVOUS")
	_add(out, "PEOPLE", "haggle_greedy", "HAGGLE: GREEDY")
	_add(out, "PEOPLE", "buyer_offer", "BUYER OFFERS")
	_add(out, "PEOPLE", "collector_pleased", "COLLECTOR PLEASED")
	_add(out, "PEOPLE", "collector_refused", "COLLECTOR REFUSED")
	for cu: String in NEW_CURSES:
		_add(out, "CURSES", "curse_" + cu, "CURSE: " + cu.replace("_", " ").to_upper())
	for m: String in MUSIC_TRACKS:
		_add(out, "MUSIC", "music_" + m, "MUSIC: " + m.to_upper())
	_add(out, "WAKES", "wake_standard", "WAKE: STANDARD")
	for w: String in WAKE_TYPES:
		_add(out, "WAKES", "wake_" + w, "WAKE: " + w.replace("_", " ").to_upper())
	_add(out, "DREAD", "dread", "DREAD SLIDER")
	for id: String in night_event_ids():
		_add(out, "NIGHTS", "event_" + id, id.replace("_", " ").to_upper())
	for id: String in ENDING_IDS:
		_add(out, "ENDINGS", "ending_" + id, "END: " + id.replace("_", " ").to_upper())
	_add(out, "BOOKS", "altar", "ALTAR, 999 ECTO")
	_add(out, "BOOKS", "journal", "JOURNAL, ALL")
	_add(out, "POPUPS", "found_page", "FOUND: PAGE")
	_add(out, "POPUPS", "found_curio", "FOUND: CURIO")
	_add(out, "POPUPS", "deed_toast", "DEED TOAST")
	_add(out, "POPUPS", "run_won", "RUN END: WON")
	_add(out, "POPUPS", "run_lost", "RUN END: LOST")
	return out


static func _add(out: Array[Dictionary], group: String, id: String, label: String) -> void:
	out.append({"id": id, "group": group, "label": label})


## Night event ids: the logic's night_events.json when it exists, else the four the plan names.
static func night_event_ids() -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = UiOccult.read_json(EVENTS_PATH) if FileAccess.file_exists(EVENTS_PATH) else null
	if raw is Dictionary and (raw as Dictionary).has("events"):
		raw = (raw as Dictionary)["events"]
	if raw is Array:
		for d: Variant in raw as Array:
			if d is Dictionary and str((d as Dictionary).get("id", "")) != "":
				out.append(str((d as Dictionary)["id"]))
	if out.is_empty():
		out.append_array(EVENT_IDS)
	return out


static func label_of(id: String) -> String:
	for t: Dictionary in tiles():
		if str(t["id"]) == id:
			return str(t["label"])
	return id


static func note_of(id: String) -> String:
	if NOTES.has(id):
		return str(NOTES[id])
	if id.begins_with("spell_"):
		return "THE SPELL IS CAST FOR YOU. CAST MORE FROM THE BAR."
	if id.begins_with("backfire_"):
		return "THE CAST GOES WRONG, ON PURPOSE."
	if id.begins_with("wake_"):
		return "SCARES: FULL OR GENTLE, SET IN THE MENU."
	if id.begins_with("event_"):
		return "DUSK OF A NIGHT WITH THIS EVENT."
	if id.begins_with("ending_"):
		return "THE END OF A WON RUN, THIS ENDING."
	if id.begins_with("table_"):
		return "THE MIDNIGHT TABLE IS OPEN. PLAY ON."
	return "PLAY ON FROM HERE."


# ---------------------------------------------------------------- building

## Sets the tile up inside `g`. `opt` carries the menu's choices: {chapter: 0-based, scares: 0 gentle / 1 full}.
## True when the tile exists. Overlay screens (setup, altar, journal) are opened through `g`.
static func build(id: String, g: ShopGame, opt: Dictionary) -> bool:
	if g.room != null and "scare_level" in g.room:
		g.room.set("scare_level", int(opt.get("scares", 1)))
	if id == "tutorial":
		g.test_begin(Tutorial.SEED, Tutorial.opts())
	elif id == "omen_draw":
		g.test_begin(SEED)
		g.test_open_setup()
	elif id.begins_with("spell_"):
		_spell(g, id.trim_prefix("spell_"), false, "")
	elif id.begins_with("backfire_"):
		_spell(g, "scry" if id.trim_prefix("backfire_") != "customer_flees" else "hex", true, id.trim_prefix("backfire_"))
	elif id.begins_with("table_"):
		_table(g, id.trim_prefix("table_"))
	elif id == "request":
		_request(g)
	elif id == "regular":
		_regular(g, REGULAR_IDS[int(opt.get("regular", 0)) % REGULAR_IDS.size()], int(opt.get("chapter", 0)))
	elif id.begins_with("regular_"):
		_regular(g, id.trim_prefix("regular_"), int(opt.get("chapter", 0)))
	elif id.begins_with("curse_") and id != "curse_jumps":
		_curse(g, id.trim_prefix("curse_"))
	elif id.begins_with("music_"):
		_music(g, id.trim_prefix("music_"))
	elif id == "buyer_offer":
		_buyer_offer(g)
	elif id.begins_with("haggle_"):
		_haggle(g, id.trim_prefix("haggle_"))
	elif id == "collector_pleased" or id == "collector_refused":
		_collector(g, id == "collector_pleased")
	elif id.begins_with("wake_"):
		_wake(g, id.trim_prefix("wake_"))
	elif id == "dread":
		_dread(g)
	elif id.begins_with("event_"):
		_night_event(g, id.trim_prefix("event_"))
	elif id.begins_with("ending_"):
		_ending(g, id.trim_prefix("ending_"))
	elif id == "altar":
		g.test_open_altar(999)
	elif id == "journal":
		g.test_open_journal()
	elif id == "found_page" or id == "found_curio":
		_found(g, id == "found_page")
	elif id == "deed_toast":
		_deed(g)
	elif id == "run_won" or id == "run_lost":
		_run_end(g, id == "run_won")
	else:
		return false
	# every helper that feeds events syncs the room itself; a sync after them would wipe the wake or effect they started
	if id == "tutorial" or id == "omen_draw" or id == "altar" or id == "journal":
		g.test_sync()
	return true


## A clean run on its first night with the first customer a seller; the shelf starts empty.
static func _run(g: ShopGame, seed_in: int = SEED) -> RunState:
	g.test_begin(seed_in)
	return g.run


## Puts an object on the shelf: by id, or the first object of a category.
static func give(g: ShopGame, which: String, curse: String = "") -> Dictionary:
	var r: RunState = g.run
	var obj: Dictionary = {}
	for o: Dictionary in g.catalog.objects:
		if str(o["id"]) == which or (obj.is_empty() and str(o["category"]) == which):
			obj = o
			if str(o["id"]) == which:
				break
	if obj.is_empty():
		obj = g.catalog.objects[0]
	var item: Dictionary = {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(obj["value"]),
		"curse": curse, "uid": r.next_uid, "est": int(obj["value"]), "tells": 0}
	r.next_uid += 1
	r.inventory.append(item)
	return item


static func _seller(g: ShopGame, item_id: String, curse: String, tid: String) -> void:
	var r: RunState = g.run
	var obj: Dictionary = {}
	for o: Dictionary in g.catalog.objects:
		if str(o["id"]) == item_id:
			obj = o
	if obj.is_empty():
		obj = g.catalog.objects[0]
	var reserve: int = maxi(1, int(round(float(obj["value"]) * r.tuning.seller_reserve_frac)))
	r.customer = {"kind": RunState.SELLER,
		"item": {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(obj["value"]), "curse": curse, "hidden": {}},
		"reserve": reserve, "ask": int(round(reserve * r.tuning.seller_ask_markup)), "patience": 3, "type": tid, "noise_u": 0.2,
		"tools": [], "tells": [], "imposter": false}


static func _buyer(g: ShopGame, category: String) -> void:
	g.run.customer = {"kind": RunState.BUYER, "category": category, "imposter": false, "type": "decorator", "pay_mult": 1.1, "cursed_mult": 1.0}


## Casts `spell` for the player. A backfire (and which kind) is found by trying seeds on a copy of the run, so the
## same cast always goes the same way.
static func _spell(g: ShopGame, spell: String, backfire: bool, kind: String) -> void:
	var r: RunState = _run(g)
	r.cash = 90
	r.spells_known = PackedStringArray(SPELL_IDS)
	r.casts_left = 4
	r.dread = r.tuning.wake_threshold * (0.55 if backfire else 0.0)
	var cursed: Dictionary = give(g, "oil_portrait", "sleepwalker")
	give(g, "hand_bell")
	if spell == "glamour":
		_buyer(g, "instrument")
		give(g, "instrument")
	elif kind == "curse_jumps" or kind == "":
		_seller(g, "mantel_clock", "", "estate_clearer")
	else:
		_seller(g, "mantel_clock", "", "estate_clearer")
	g.test_sync()
	var cmd: Dictionary = UiOccult.cast_command(spell, int(cursed["uid"]))
	for s: int in range(1, 700):
		var probe := RunState.new()
		probe.restore(r.snapshot(), g.catalog)
		probe.rng.seed = s
		var ev: Array[Dictionary] = probe.apply(cmd)
		var went_wrong: bool = false
		var got_kind: String = ""
		for e: Dictionary in ev:
			if str(e["e"]) == "cast":
				went_wrong = bool(e.get("backfire", false))
			if str(e["e"]) == "backfire":
				got_kind = str(e.get("kind", ""))
		if went_wrong == backfire and (kind == "" or got_kind == kind):
			r.rng.seed = s
			g.act(cmd)
			return
	g.act(cmd)


static func _table(g: ShopGame, game: String) -> void:
	var r: RunState = _run(g, 11)
	r.cash = 140
	r.night = 2
	var held: Dictionary = give(g, "mantel_clock")
	give(g, "hand_bell", "sleepwalker")
	r.customer = {}
	r.phase = RunState.PHASE_TABLE
	r.table = {"games_left": 4, "lots_left": 2, "hand": {}, "pairs": {}}
	g.test_sync()
	g.test_feed([{"e": "table_open", "night": 1, "games_left": 4, "lots_left": 2}] as Array[Dictionary])
	g.cards.clear()
	var tb: UiTable = g.hud.table
	tb.stake = 6
	match game:
		"dice":
			g.activate("t_dice_high")
		"hand":
			g.activate("t_hand")
		"wheel":
			g.activate("t_wheel")
		"pairs":
			g.activate("t_pairs")
			g.activate("pair:0")
			g.activate("pair:1")
		"item":
			g.act({"t": "table_stake_item", "uid": int(held["uid"])})
		"lot":
			g.activate("t_lot")


static func _request(g: ShopGame) -> void:
	var r: RunState = _run(g, 7)
	r.night = 2
	var want: Dictionary = {"category": "book", "curse": "", "item_id": ""}
	var item: Dictionary = give(g, "book")
	r.requests = [{"id": "req_test", "who": "Mrs. Pell", "tid": "widow", "want": want, "due": 2, "pay_mult": 1.8, "reward": {}, "called": true}]
	r.customer = {"kind": RunState.BUYER, "category": str(item["category"]), "imposter": false, "type": "widow", "pay_mult": 1.0,
		"cursed_mult": 1.0, "request": true, "request_id": "req_test", "who": "Mrs. Pell", "want": want}
	g.test_sync()
	g.test_feed([{"e": "customer", "kind": RunState.BUYER, "category": str(item["category"]), "type": "Mrs. Pell", "tid": "widow",
		"line": "My order. You promised.", "request": true, "who": "Mrs. Pell"}] as Array[Dictionary])
	g.selected_uid = int(item["uid"])
	g.test_later(2.5, func() -> void: g.act({"t": "sell", "uid": int(item["uid"])}))


## A seller of the given mood, and a first low offer so the counter-offer shows the mood.
static func _haggle(g: ShopGame, mood: String) -> void:
	var r: RunState = _run(g, 8)
	_seller(g, "mantel_clock", "", "estate_clearer")
	r.customer["mood"] = mood
	r.customer["patience"] = 4
	var line: String = str((Moods.get_mood(mood).get("lines", [""]) as Array)[0])
	g.test_sync()
	g.test_feed([{"e": "customer", "kind": RunState.SELLER, "name": "Mantel clock", "ask": r.customer["ask"], "type": "Estate clearer",
		"tid": "estate_clearer", "line": "Make me an offer.", "mood": mood, "mood_line": line}] as Array[Dictionary])
	g.test_later(1.2, func() -> void: g.act({"t": "offer", "amount": maxi(1, int(r.customer["ask"]) / 2)}))
	g.test_later(2.6, func() -> void: g.act({"t": "offer", "amount": maxi(1, int(r.customer["ask"]) * 3 / 5)}))


## A counter object with the curse, one tool used, the held object carrying the same curse, then the look-closer card.
static func _curse(g: ShopGame, curse: String) -> void:
	var r: RunState = _run(g, 17)
	r.night = 2
	give(g, "mantel_clock", curse)
	give(g, "hand_bell")
	_seller(g, "oil_portrait", curse, "estate_clearer")
	g.test_sync()
	g.test_later(0.6, func() -> void: g.act({"t": "inspect", "tool": "listen"}))
	g.test_later(1.4, func() -> void: g.act({"t": "inspect", "tool": "uv"}))
	g.test_later(2.4, func() -> void: g.open_inspect(-1))


## Plays one music track and walks its layers: calm, then half Dread, then full.
static func _music(g: ShopGame, track: String) -> void:
	g.test_begin(SEED)
	var steps: Array = [[0.3, 0.0, "LAYER 1: BASE"], [3.5, 0.6, "LAYER 2: UNEASE"], [7.0, 1.0, "LAYER 3: DREAD"]]
	for st: Array in steps:
		g.test_later(float(st[0]), func() -> void:
			if g.sfx == null or g.sfx.music == null:
				return
			g.sfx.music.play_track(track)
			g.sfx.music.set_intensity(float(st[1]))
			g._log("MUSIC %s, %s" % [track.to_upper(), str(st[2])]))


## An ordinary buyer opens with an offer on a held clock; after a moment the player counters once.
static func _buyer_offer(g: ShopGame) -> void:
	var r: RunState = _run(g, 8)
	var held: Dictionary = give(g, "mantel_clock")
	give(g, "hand_bell")
	var price: int = maxi(4, r.sale_price(held))
	r.customer = {"kind": RunState.BUYER, "category": str(held["category"]), "imposter": false, "type": "decorator", "tid": "decorator",
		"pay_mult": 1.1, "cursed_mult": 1.0, "mood": "greedy", "patience": 3, "limit": price + maxi(1, price / 4), "noise_u": 0.2,
		"offer": {"uid": held["uid"], "price": price}}
	g.test_sync()
	g.test_feed([{"e": "customer", "kind": RunState.BUYER, "name": "Decorator", "type": "Decorator", "tid": "decorator", "line": "I want something old.",
		"mood": "greedy", "mood_line": "", "category": held["category"]},
		{"e": "buyer_offer", "uid": held["uid"], "name": held["name"], "offer": price, "patience": 3, "mood": "greedy", "tell": "", "counter": false}] as Array[Dictionary])
	g.test_later(2.0, func() -> void: g.act({"t": "counter", "amount": price + maxi(2, price / 2)}))


static func _regular(g: ShopGame, id: String, chapter: int) -> void:
	var r: RunState = _run(g, 31)
	var count: int = Regulars.chapter_count(id)
	var ch: int = clampi(chapter, 0, maxi(count - 1, 0))
	var chap: Dictionary = Regulars.chapter(id, ch)
	r.night = 3
	r.regular = {"id": id, "night": 3, "chapter": ch, "state": ""}
	if str(chap.get("kind", "")) == RunState.BUYER:
		var want: String = str(chap.get("item_id", ""))
		give(g, want if want != "" else str(chap.get("category", "toy")), str(chap.get("curse", "")))
	r.customer = {}
	var ev: Array[Dictionary] = []
	r.call("_next_customer", ev)
	g.test_sync()
	g.test_feed(ev)


static func _collector(g: ShopGame, pleased: bool) -> void:
	var r: RunState = _run(g, 5)
	var nights: int = int(r.tuning.nights)
	r.night = nights
	var want: Dictionary = Collector.roll_want(SEED)
	r.collector = {"want": want, "rolled": true, "arrived": false, "done": false, "result": ""}
	var held: Dictionary = give(g, str(want["category"]) if str(want["category"]) != "" else "relic", str(want["curse"]))
	if str(want["curse"]) != "" and str(held["curse"]) == "":
		held["curse"] = str(want["curse"])
	r.cash = 150
	r.customer = {}
	var ev: Array[Dictionary] = []
	r.call("_next_customer", ev)
	g.test_sync()
	g.test_feed(ev)
	g.selected_uid = int(held["uid"])
	g.test_later(6.2, func() -> void:
		g.act({"t": "sell", "uid": int(held["uid"])} if pleased else {"t": "pass"}))


static func _wake(g: ShopGame, type_id: String) -> void:
	var r: RunState = _run(g, 21)
	r.night = 2
	give(g, "mantel_clock", "sleepwalker")
	give(g, "hand_bell")
	r.dread = r.tuning.wake_threshold
	r.customer = {}
	g.test_sync()
	var w: Dictionary = {"e": "wake", "night": 2, "dread": r.dread, "broke": "", "closed": false}
	if type_id != "standard":
		w["wake_type"] = type_id
	g.test_feed([w] as Array[Dictionary])
	g.cards.clear()  # the SOMETHING WOKE card would cover the room; the wake itself is the point here


static func _dread(g: ShopGame) -> void:
	var r: RunState = _run(g, 9)
	give(g, "mantel_clock", "sleepwalker")
	give(g, "hand_bell")
	r.dread = 0.0
	g.test_sync()
	g.test_slider = true


static func _night_event(g: ShopGame, id: String) -> void:
	var r: RunState = _run(g, 13)
	r.night = 2
	give(g, "hand_bell")
	g.test_sync()
	g.test_feed([{"e": "night_event", "id": id, "night": 2}] as Array[Dictionary])


static func _ending(g: ShopGame, id: String) -> void:
	var r: RunState = _run(g, 17)
	r.night = int(r.tuning.nights)
	r.cash = 240
	give(g, "mantel_clock", "sleepwalker" if id == "cursed_shop" else "")
	if id == "cursed_shop":
		r.dread = r.tuning.wake_threshold * 0.8
	r.phase = RunState.PHASE_OVER
	r.won = true
	r.customer = {}
	if id == "collector":
		r.collector = {"want": Collector.roll_want(SEED), "rolled": true, "arrived": true, "done": true, "result": "pleased"}
	r.opts["ending"] = id
	g.test_sync()
	g.test_feed([{"e": "run_won", "cash": r.cash, "ending": id}] as Array[Dictionary])


static func _found(g: ShopGame, page: bool) -> void:
	_run(g, 3)
	g.test_sync()
	var f: Dictionary = {"kind": "page", "id": "banish"} if page else {"kind": "curio", "id": ""}
	if not page:
		var rare: String = ""
		for c: Dictionary in g.catalog.curios:
			if str(c.get("rarity", "")) == "rare":
				rare = str(c["id"])
		f["id"] = rare if rare != "" else str(g.catalog.curios[0]["id"])
	g.test_feed([{"e": "found", "kind": str(f["kind"]), "id": str(f["id"])}] as Array[Dictionary])


static func _deed(g: ShopGame) -> void:
	_run(g, 3)
	g.test_sync()
	var defs: Array[Dictionary] = UiLedger.deed_defs()
	g.hud.toasts.push_deed(str(defs[0]["id"]) if not defs.is_empty() else "first_blood")
	if defs.size() > 1:
		g.hud.toasts.push_deed(str(defs[1]["id"]))


static func _run_end(g: ShopGame, won: bool) -> void:
	var r: RunState = _run(g, 19)
	r.night = int(r.tuning.nights) if won else 3
	r.cash = 210 if won else 12
	give(g, "mantel_clock", "sleepwalker")
	r.phase = RunState.PHASE_OVER
	r.won = won
	r.customer = {}
	g.ecto_earned = 34
	g.test_sync()
	if won:
		g.test_feed([{"e": "run_won", "cash": r.cash}] as Array[Dictionary])
	else:
		g.test_feed([{"e": "run_lost", "night": r.night, "cash": r.cash, "rent": 40}] as Array[Dictionary])
