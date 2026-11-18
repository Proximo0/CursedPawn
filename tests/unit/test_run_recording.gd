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
