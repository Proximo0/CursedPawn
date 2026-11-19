extends TestCase


func test_number_counts_from_launch() -> void:
	assert_eq(Daily.number(2026, 12, 18), 1)
	assert_eq(Daily.number(2026, 12, 19), 2)
	assert_eq(Daily.number(2027, 1, 1), 15)
	assert_eq(Daily.number(2026, 12, 17), 0)
	assert_eq(Daily.number(2028, 3, 1) - Daily.number(2028, 2, 28), 2, "leap day")


func test_seed_is_stable_and_differs() -> void:
	assert_eq(Daily.seed_for(2026, 12, 18), Daily.seed_for(2026, 12, 18))
	assert_true(Daily.seed_for(2026, 12, 18) != Daily.seed_for(2026, 12, 19))
	assert_true(Daily.seed_for(2026, 12, 18) >= 0)
	assert_eq(Daily.seed_for(2026, 12, 18), 1711319059, "pinned: a change would move every player's daily")


func test_opts_use_first_offered_omen() -> void:
	var s: int = Daily.seed_for(2026, 12, 20)
	var o: Dictionary = Daily.opts_for(s)
	assert_eq(o["omen"], Omens.offer(s)[0])
	assert_eq(o["haunting"], 0)
	assert_true(o["daily"])


func test_result_text() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	run.start(Daily.seed_for(2026, 12, 18), cat, Tuning.new(), {}, Daily.opts_for(Daily.seed_for(2026, 12, 18)))
	run.night = 5
	run.won = true
	run.cash = 412
	run.wake_nights.assign([3, 3, 4])
	var lines: PackedStringArray = Daily.result_text(run, 12).split("\n")
	assert_eq(lines.size(), 4)
	assert_eq(lines[0], "Cursed Pawn Séance #12")
	assert_eq(lines[1], "Night 5/5 survived | 412 coins | woke 3x")
	assert_eq(lines[2], "🕯🕯🔥🔥🕯")
	assert_true(lines[3].begins_with("Omen: "))
	run.won = false
	run.night = 3
	run.wake_nights.assign([2])
	assert_eq(Daily.result_text(run, 12).split("\n")[2], "🕯🔥💀▫▫")
	assert_true(Daily.result_text(run, 12).split("\n")[1].begins_with("Night 3/5 lost"))
