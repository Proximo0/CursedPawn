extends TestCase


func _game(seed_in: int) -> ShopGame:
	var g := ShopGame.new()
	g.catalog = Catalog.load_default()
	g.new_run(seed_in)
	return g


func _seller_run() -> RunState:
	var cat: Catalog = Catalog.load_default()
	var run := RunState.new()
	run.start(3, cat, Tuning.new())
	run.customer = {"kind": RunState.SELLER, "tools": ["touch"], "ask": 40}
	return run


func test_view_mapping_uses_whole_scales_with_letterbox() -> void:
	assert_eq(ShopGame.VIEW, Vector2(640.0, 360.0))
	assert_eq(ShopGame.ui_scale(Vector2(1280, 720)), 2.0)
	assert_eq(ShopGame.ui_scale(Vector2(1920, 1080)), 3.0)
	assert_eq(ShopGame.ui_scale(Vector2(1600, 900)), 2.0, "2.5 fit keeps 80 percent at 2x")
	assert_eq(ShopGame.ui_scale(Vector2(1000, 563)), 1.5625, "too far from a whole number: plain fit")
	assert_eq(ShopGame.ui_scale(Vector2(480, 270)), 0.75, "tiny windows fit")
	assert_eq(ShopGame.ui_to_view(Vector2(0, 0), Vector2(1280, 720)), Vector2(0, 0))
	assert_eq(ShopGame.ui_to_view(Vector2(1280, 720), Vector2(1280, 720)), Vector2(640, 360))
	assert_eq(ShopGame.ui_to_view(Vector2(960, 540), Vector2(1920, 1080)), Vector2(320, 180))
	# a wider window letterboxes left and right: the centre stays the centre
	assert_eq(ShopGame.ui_to_view(Vector2(1000, 360), Vector2(2000, 720)), Vector2(320, 180))
	assert_eq(ShopGame.ui_rect(Vector2(1400, 720)), Rect2(60, 0, 1280, 720))


func test_seller_keys_map_to_commands() -> void:
	var run: RunState = _seller_run()
	assert_eq(ShopGame.ui_key_command(KEY_1, run, 9, -1), {"t": "inspect", "tool": "uv"})
	assert_eq(ShopGame.ui_key_command(KEY_2, run, 9, -1), {"t": "inspect", "tool": "scale"})
	assert_eq(ShopGame.ui_key_command(KEY_3, run, 9, -1), {"t": "inspect", "tool": "listen"})
	assert_eq(ShopGame.ui_key_command(KEY_4, run, 9, -1), {}, "touch is already used")
	assert_eq(ShopGame.ui_key_command(KEY_ENTER, run, 9, -1), {"t": "offer", "amount": 9})
	assert_eq(ShopGame.ui_key_command(KEY_B, run, 9, -1), {"t": "buy"})
	assert_eq(ShopGame.ui_key_command(KEY_P, run, 9, -1), {"t": "pass"})
	assert_eq(ShopGame.ui_key_command(KEY_Z, run, 9, -1), {})


func test_buyer_keys_map_to_commands() -> void:
	var run: RunState = _seller_run()
	run.customer = {"kind": RunState.BUYER, "category": "toy"}
	assert_eq(ShopGame.ui_key_command(KEY_ENTER, run, 9, -1), {}, "nothing picked")
	assert_eq(ShopGame.ui_key_command(KEY_ENTER, run, 9, 7), {"t": "sell", "uid": 7})
	assert_eq(ShopGame.ui_key_command(KEY_P, run, 9, -1), {"t": "pass"})
	assert_eq(ShopGame.ui_key_command(KEY_B, run, 9, -1), {})
	run.customer = {}
	assert_eq(ShopGame.ui_key_command(KEY_P, run, 9, -1), {})


func test_activate_buttons_drive_the_run() -> void:
	var g: ShopGame = _game(5)
	if str(g.run.customer.get("kind", "")) != RunState.SELLER:
		g.activate("pass")
	var before: int = g.rec.commands.size()
	g.activate("inc")
	assert_eq(g.rec.commands.size(), before, "inc only moves the stake")
	g.activate("tool:uv")
	assert_eq(g.rec.commands.size(), before + 1)
	assert_eq(str(g.rec.commands[before]["tool"]), "uv")


func test_offer_row_clamps_to_cash() -> void:
	var g: ShopGame = _game(5)
	g.offer_amount = 99999
	g.activate("inc")
	assert_true(g.offer_amount <= maxi(1, g.run.cash))
	g.offer_amount = 1
	g.activate("dec")
	assert_eq(g.offer_amount, 1)


func test_bot_run_through_act_reaches_end_screen_with_code() -> void:
	for style: String in ShopBot.STYLES:
		var g: ShopGame = _game(7)
		var bot := ShopBot.new(style)
		var guard: int = 0
		while not g.run.is_over() and guard < 5000:
			g.act(bot.decide(g.run))
			guard += 1
		assert_true(g.run.is_over(), style + " finished")
		assert_true(g.is_end_screen())
		assert_false(g.cards.is_empty(), "title card queued")
		g.cards.clear()
		assert_true(g.end_panel_visible())
		assert_true(g.pass_text() != "" or g.run.inventory.is_empty(), style + " pass-on code")
		g.act({"t": "pass"})  # a finished run ignores commands
		assert_true(g.run.is_over())


func test_new_run_after_end_and_gift_paste() -> void:
	var g: ShopGame = _game(7)
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	while not g.run.is_over():
		g.act(bot.decide(g.run))
	g.cards.clear()
	var code: String = g.pass_text()
	g.paste_gift("nonsense")
	assert_true(g.gift_status.contains("NO LINK") or g.gift_status.contains("DID NOT TAKE"), g.gift_status)
	g.paste_gift("")
	assert_true(g.gift_status.contains("NO LINK"))
	if code != "":
		g.paste_gift(code)
		assert_true(g.gift_status.begins_with("READY"), g.gift_status)
	g.activate("newrun")
	assert_false(g.run.is_over())
	assert_eq(g.seed_now, 8)
	assert_eq(g.gift_text, "")


func test_replay_plays_back_a_wake() -> void:
	var found: ShopGame = null
	for s: int in range(1, 40):
		var g: ShopGame = _game(s)
		var bot := ShopBot.new(ShopBot.GREEDY)
		var guard: int = 0
		while not g.run.is_over() and guard < 5000:
			g.act(bot.decide(g.run))
			guard += 1
		if not g.rec.wake_at.is_empty():
			found = g
			break
	assert_true(found != null, "some greedy run wakes")
	if found == null:
		return
	found.start_replay()
	assert_true(found.is_replaying())
	assert_false(found.is_end_screen(), "the replay hides the end screen")
	var hash_before: int = found.run.state_hash()
	var guard: int = 0
	while found.is_replaying() and guard < 400:
		found._replay_tick(1.0)
		guard += 1
	assert_false(found.is_replaying())
	assert_eq(found.run.state_hash(), hash_before, "replay never touches the real run")


func test_replay_without_a_wake_is_a_no_op() -> void:
	var g: ShopGame = _game(3)
	g.start_replay()
	assert_false(g.is_replaying())


func test_cards_queue_for_night_and_wake() -> void:
	var g: ShopGame = _game(3)
	assert_true(g.cards.size() >= 1, "night 1 card")
	assert_eq(str(g.cards[0]["title"]), "NIGHT 1")
	var ev: Array[Dictionary] = [{"e": "wake", "night": 1, "dread": 5.0, "broke": "Mug", "closed": false}]
	g._on_events(ev)
	assert_eq(str(g.cards[g.cards.size() - 1]["title"]), "SOMETHING WOKE")


func test_estimate_and_clock_text() -> void:
	assert_eq(ShopGame.ui_estimate_text({"mid": 27, "spread": 0.5}), "~27 +-50%")
	assert_eq(ShopGame.ui_estimate_text({}), "?")
	assert_eq(ShopGame.ui_clock_text(12.2), "13M LEFT")


func test_collector_events_get_ledger_lines_and_cards() -> void:
	assert_true(ShopGame.ui_event_line({"e": "request_new", "who": "Mrs Pell", "want_text": "cursed doll"}).contains("Pell"))
	assert_false(ShopGame.ui_event_line({"e": "request_done", "pay": 9}).begins_with("Unknown"))
	assert_eq(ShopGame.ui_event_line({"e": "run_opts"}), "", "silent")
	assert_true(ShopGame.ui_event_line({"e": "collector_omen", "text": "a locket", "night": 3}).contains("LOCKET") or ShopGame.ui_event_line({"e": "collector_omen", "text": "a locket"}).to_upper().contains("LOCKET"))
	var g: ShopGame = _game(5)
	g.cards.clear()
	g._on_events([{"e": "collector_arrives", "want_text": "a cursed doll", "line": "I collect."}] as Array[Dictionary])
	assert_eq(str(g.cards[0]["style"]), "collector")
	assert_true(float(g.cards[0]["secs"]) > ShopGame.CARD_SECS)
	g.free()
