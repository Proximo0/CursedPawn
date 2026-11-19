extends TestCase


func test_replay_matches_and_round_trips() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	var rec := RunRecording.begin(run, 13, cat, Tuning.new())
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	assert_true(bot.play(run, rec), "finished")
	assert_eq(rec.first_divergence(cat), -1, "replay matches")
	assert_eq(rec.replay(cat).state_hash(), run.state_hash(), "final hash")
	var back := RunRecording.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
	assert_eq(back.first_divergence(cat), -1, "after JSON")


func test_partial_replay() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	var rec := RunRecording.begin(run, 2, cat, Tuning.new())
	var bot := ShopBot.new(ShopBot.GREEDY)
	for i: int in range(10):
		rec.drive(run, bot.decide(run))
	assert_eq(rec.replay(cat, 4).state_hash(), rec.hashes[3])


func test_wake_clip() -> void:
	var cat := Catalog.load_default()
	var tun := Tuning.new()
	tun.set_value("cursed_share", 1.0)
	tun.set_value("wake_threshold", 1.0)
	tun.set_value("dread_on_buy", 2.0)  # even the mildest curse (dread 0.6) wakes on buying
	tun.set_value("start_cash", 1000.0)
	var run := RunState.new()
	var rec := RunRecording.begin(run, 9, cat, tun)
	rec.drive(run, {"t": "pass"})
	rec.drive(run, {"t": "buy"})
	assert_eq(rec.wake_at.size(), 1)
	assert_eq(rec.wake_clip(0, 5), Vector2i(0, 2))


func test_replay_with_opts() -> void:
	var cat := Catalog.load_default()
	for opts: Dictionary in [{"haunting": 10, "omen": "regular_crowd"}, {"haunting": 3, "omen": "open_book", "daily": true}]:
		var run := RunState.new()
		var rec := RunRecording.begin(run, 31, cat, Tuning.new(), {}, opts)
		assert_true(ShopBot.new(ShopBot.CAUTIOUS).play(run, rec))
		assert_eq(rec.first_divergence(cat), -1, "replay matches with opts")
		var back := RunRecording.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
		assert_eq(back.first_divergence(cat), -1, "after JSON")
		assert_eq(back.replay(cat).opts, run.opts)


func test_replay_matches_a_tutorial_run() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	var rec := RunRecording.begin(run, Tutorial.SEED, cat, Tuning.new(), {}, Tutorial.opts())
	assert_true(ShopBot.new(ShopBot.CAUTIOUS).play(run, rec), "finished")
	assert_eq(rec.first_divergence(cat), -1, "replay matches")
	var back := RunRecording.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
	assert_eq(back.first_divergence(cat), -1, "after JSON")
	assert_true(back.replay(cat).opts.get("tutorial", false), "the option is replayed")


func test_replay_matches_a_regular_visit() -> void:
	var cat := Catalog.load_default()
	var tun := Tuning.new()
	tun.set_value("regular_chance", 1.0)
	for s: int in range(1, 40):
		var run := RunState.new()
		var rec := RunRecording.begin(run, s, cat, tun, {}, {"regulars": {}})
		ShopBot.new(ShopBot.GREEDY).play(run, rec)
		if str(run.regular.get("state", "")) == "":
			continue
		assert_eq(rec.first_divergence(cat), -1, "replay matches with a visit (seed %d)" % s)
		var back := RunRecording.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
		assert_eq(back.replay(cat).state_hash(), run.state_hash(), "after JSON")
		assert_eq(back.replay(cat).regular_progress, run.regular_progress)
		return
	assert_true(false, "no seed brought a visit")
