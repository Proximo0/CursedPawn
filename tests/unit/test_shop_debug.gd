extends TestCase

const SD_EVENTS: Array = [
	{"e": "night_start", "night": 2, "rent": 60},
	{"e": "customer", "kind": "seller", "name": "Mug", "ask": 40},
	{"e": "customer", "kind": "buyer", "category": "toy"},
	{"e": "inspected", "tool": "uv", "tell": "glows", "estimate": {"mid": 50, "spread": 0.3}},
	{"e": "counter", "offer": 10, "ask": 30, "patience": 2},
	{"e": "left", "offer": 5},
	{"e": "bought", "uid": 1, "name": "Mug", "price": 20},
	{"e": "sold", "uid": 1, "name": "Mug", "price": 50, "imposter": false},
	{"e": "passed", "kind": "seller"},
	{"e": "wake", "night": 3, "dread": 4.5, "broke": "Mug", "closed": true},
	{"e": "night_end", "night": 1, "rent": 40, "cash": 90},
	{"e": "run_lost", "night": 2, "cash": 5, "rent": 60},
	{"e": "run_won", "cash": 300},
	{"e": "invalid", "why": "tool uv"},
	{"e": "wager", "card": "The Fool", "text": "Luck turns.", "stake": 10, "payout": 20, "dread": 1.0},
]


func test_every_event_has_text() -> void:
	for e: Dictionary in SD_EVENTS:
		var s: String = ShopDebug.sd_event_text(e)
		assert_true(s != "" and not s.begins_with("Unknown"), str(e["e"]))


func test_event_details() -> void:
	assert_true(ShopDebug.sd_event_text(SD_EVENTS[3]).contains("50 +- 30%"))
	assert_true(ShopDebug.sd_event_text(SD_EVENTS[9]).contains("Mug"))
	assert_true(ShopDebug.sd_event_text({"e": "zzz"}).begins_with("Unknown"))


func test_estimate_text() -> void:
	assert_eq(ShopDebug.sd_estimate_text({}), "?")


func test_overlay_format() -> void:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	var s: String = DebugOverlay.ov_format(run.debug_frame())
	assert_true(s.contains("night 1") and s.contains("night_start"))


func test_wager_text() -> void:
	var t: String = ShopDebug.sd_event_text(SD_EVENTS[14])
	assert_true(t.contains("The Fool") and t.contains("Luck turns.") and t.contains("payout 20"))


func test_wager_through_run() -> void:
	var run := RunState.new()
	var rec := RunRecording.begin(run, 5, Catalog.load_default(), Tuning.new())
	var ev: Array[Dictionary] = rec.drive(run, {"t": "wager", "amount": maxi(1, run.max_wager())})
	assert_true(ev.size() > 0 and ShopDebug.sd_event_text(ev[0]) != "" and not ShopDebug.sd_event_text(ev[0]).begins_with("Unknown"))


func test_end_screen_passes_on_and_gift_starts_next_run() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var sd: ShopDebug = (load("res://game/shop/shop_debug.tscn") as PackedScene).instantiate()
	tree.root.add_child(sd)
	var bot := ShopBot.new(ShopBot.GREEDY)
	var guard: int = 0
	while not sd.run.is_over() and guard < RunState.MAX_COMMANDS:
		sd.act(bot.decide(sd.run))
		guard += 1
	sd.run.inventory.assign([{"uid": 99, "id": sd.catalog.objects[0]["id"], "name": sd.catalog.objects[0]["name"],
		"category": sd.catalog.objects[0]["category"], "value": 10, "curse": sd.catalog.curses[0]["id"], "est": 5,
		"tells": 0}])
	var text: String = sd.pass_text()
	assert_true(text.begins_with(PassLink.CODE_VERSION), "a code on desktop")
	sd._gift_edit.text = text
	sd._on_new_run()
	assert_eq(sd.run.inventory.size(), 1, "gift in the new shop")
	assert_eq(sd.run.inventory[0]["curse"], sd.catalog.curses[0]["id"])
	assert_eq(sd.rec.gift["id"], sd.catalog.objects[0]["id"], "recorded for replay")
	sd.free()


func test_instant_replay_rebuilds_the_wake_and_returns() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var sd: ShopDebug = (load("res://game/shop/shop_debug.tscn") as PackedScene).instantiate()
	tree.root.add_child(sd)
	var bot := ShopBot.new(ShopBot.GREEDY)
	var guard: int = 0
	while sd.rec.wake_at.is_empty() and not sd.run.is_over() and guard < RunState.MAX_COMMANDS:
		sd.act(bot.decide(sd.run))
		guard += 1
	assert_false(sd.rec.wake_at.is_empty(), "the greedy bot wakes something on the default seed")
	var live_hash: int = sd.run.state_hash()
	sd.start_replay()
	assert_true(sd._replay_run != null, "replay running")
	sd.act({"t": "pass"})
	assert_eq(sd.run.state_hash(), live_hash, "no commands reach the live run during a replay")
	var steps: int = 0
	while sd._replay_cmds.size() > 0 and steps < 20:
		sd._replay_tick(10.0)
		steps += 1
	var at: int = sd.rec.wake_at[-1]
	assert_eq(sd._replay_run.state_hash(), sd.rec.hashes[at], "replay reaches the recorded wake exactly")
	sd._replay_tick(10.0)
	assert_true(sd._replay_run == null, "back to the live shop")
	sd.free()
