extends TestCase


func test_bot_report_and_ok() -> void:
	var run := RunState.new()
	run.start(7, Catalog.load_default(), Tuning.new())
	var bot := ShopBot.new(ShopBot.GREEDY)
	assert_true(bot.play(run))
	var r: Dictionary = BotPilot.bot_report(run, false, -1)
	assert_eq(r["hash"], str(run.state_hash()))
	assert_true(r["over"])
	assert_true(BotPilot.bot_ok(r))
	r["diverged"] = 3
	assert_true(not BotPilot.bot_ok(r))
	assert_true(not BotPilot.bot_ok(BotPilot.bot_report(run, true, -1)))
