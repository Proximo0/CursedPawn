extends TestCase


func cc_make(seed_value: int = 1) -> CurioCollection:
	return CurioCollection.create(seed_value, Tuning.new())


func test_odds_sum_to_one() -> void:
	var o: Dictionary = cc_make().odds()
	assert_near(float(o["common"]) + float(o["rare"]) + float(o["legendary"]), 1.0)


func test_no_box_no_open() -> void:
	assert_true(cc_make().open_box().is_empty())


func test_pity_guarantees_legendary() -> void:
	var tun := Tuning.new()
	tun.set_value("box_legendary_odds", 0.0)
	tun.set_value("box_pity", 10.0)
	var c := CurioCollection.create(3, tun)
	c.add_boxes(10)
	var last: Dictionary = {}
	for i: int in range(10):
		last = c.open_box()
	assert_eq(last["rarity"], "legendary")
	assert_true(last["pity"])
	assert_eq(c.since_legendary, 0)


func test_measured_odds_match_published() -> void:
	var tun := Tuning.new()
	tun.set_value("box_pity", 200.0)
	var c := CurioCollection.create(5, tun)
	c.add_boxes(4000)
	var n: Dictionary = {"common": 0, "rare": 0, "legendary": 0}
	for i: int in range(4000):
		var r: String = c.open_box()["rarity"]
		n[r] = int(n[r]) + 1
	assert_near(float(n["rare"]) / 4000.0, 0.25, 0.03, "rare")
	assert_near(float(n["legendary"]) / 4000.0, 0.05, 0.02, "legendary")


func test_new_curios_before_duplicates() -> void:
	var tun := Tuning.new()
	tun.set_value("box_rare_odds", 0.0)
	tun.set_value("box_legendary_odds", 0.0)
	tun.set_value("box_pity", 200.0)
	var c := CurioCollection.create(7, tun)
	c.add_boxes(6)
	for i: int in range(6):
		assert_true(c.open_box()["new"], "box %d" % i)
	assert_eq(c.complete_count(), 6)


func test_won_run_earns_box() -> void:
	var c := cc_make()
	var run := RunState.new()
	run.start(1, Catalog.load_default(), Tuning.new())
	run.won = true
	assert_eq(c.reward_run(run), 1)
	assert_eq(c.boxes, 1)


func test_round_trip() -> void:
	var c := cc_make(9)
	c.add_boxes(5)
	c.open_box()
	var d := cc_make(9)
	d.from_dict(c.to_dict())
	assert_eq(d.open_box(), c.open_box())


func test_paid_box_curios_are_never_tradeable() -> void:
	var c := cc_make(11)
	c.add_boxes(3, true)
	for i: int in range(3):
		var r: Dictionary = c.open_box()
		assert_false(r["tradeable"], "paid box %d" % i)
	assert_true(c.tradeable.is_empty())
	assert_false(c.take_tradeable(str(c.owned.keys()[0])))


func test_free_boxes_open_first_and_trade() -> void:
	var c := cc_make(12)
	c.add_boxes(1, true)
	c.add_boxes(1)
	assert_true(c.open_box()["tradeable"], "free first")
	assert_false(c.open_box()["tradeable"], "then paid")
	assert_eq(c.paid_boxes, 0)


func test_granted_curio_trades_once() -> void:
	var c := cc_make()
	assert_true(c.grant("curio_01"))
	assert_true(c.take_tradeable("curio_01"))
	assert_false(c.take_tradeable("curio_01"))
	assert_false(c.owned.has("curio_01"))
