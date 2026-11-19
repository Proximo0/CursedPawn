extends TestCase


func cc_make(seed_value: int = 1, tun: Tuning = null) -> CurioCollection:
	return CurioCollection.create(seed_value, tun if tun != null else Tuning.new())


func cc_commons_only() -> Tuning:
	var tun := Tuning.new()
	tun.set_value("box_rare_odds", 0.0)
	tun.set_value("box_legendary_odds", 0.0)
	tun.set_value("box_pity", 200.0)
	tun.set_value("box_soft_pity_start", 200.0)
	return tun


func test_odds_sum_to_one() -> void:
	var o: Dictionary = cc_make().odds()
	assert_near(float(o["common"]) + float(o["rare"]) + float(o["legendary"]), 1.0)


func test_no_box_no_open() -> void:
	assert_true(cc_make().open_box().is_empty())


func test_hard_pity_guarantees_legendary() -> void:
	var tun := Tuning.new()
	tun.set_value("box_legendary_odds", 0.0)
	tun.set_value("box_soft_pity_step", 0.0)
	tun.set_value("box_pity", 10.0)
	var c := cc_make(3, tun)
	c.add_boxes(10)
	var last: Dictionary = {}
	for i: int in range(10):
		last = c.open_box()
	assert_eq(last["rarity"], "legendary")
	assert_true(last["pity"])
	assert_eq(c.since_legendary, 0)


func test_soft_pity_raises_shown_odds() -> void:
	var c := cc_make()
	var base: float = float(c.odds()["legendary"])
	c.since_legendary = 24
	assert_near(float(c.odds()["legendary"]), base + 5 * 0.06)


func test_measured_odds_match_published() -> void:
	var tun := Tuning.new()
	tun.set_value("box_pity", 200.0)
	tun.set_value("box_soft_pity_start", 200.0)
	var c := cc_make(5, tun)
	c.add_boxes(4000)
	var n: Dictionary = {"common": 0, "rare": 0, "legendary": 0}
	for i: int in range(4000):
		var r: String = c.open_box()["rarity"]
		n[r] = int(n[r]) + 1
	assert_near(float(n["rare"]) / 4000.0, 0.25, 0.03, "rare")
	assert_near(float(n["legendary"]) / 4000.0, 0.05, 0.02, "legendary")


func test_new_curios_before_duplicates() -> void:
	var c := cc_make(7, cc_commons_only())
	c.add_boxes(6)
	for i: int in range(6):
		assert_true(c.open_box()["new"], "box %d" % i)
	assert_eq(c.complete_count(), 6)


func test_paid_box_curios_are_locked_and_dupes_become_locked_shards() -> void:
	var c := cc_make(11, cc_commons_only())
	c.add_boxes(16, true)
	var shards: int = 0
	for i: int in range(16):
		var r: Dictionary = c.open_box()
		assert_false(r["tradeable"], "paid box %d" % i)
		shards += int(r["shards"])
	assert_true(c.tradeable.is_empty())
	assert_eq(shards, 2, "two duplicates of fourteen commons")
	assert_eq(c.shards_locked, 2)
	assert_eq(c.shards_free, 0)


func test_free_boxes_open_first_and_trade() -> void:
	var c := cc_make(12)
	c.add_boxes(1, true)
	c.add_boxes(1)
	assert_true(c.open_box()["tradeable"], "free first")
	assert_false(c.open_box()["tradeable"], "then paid")
	assert_eq(c.boxes(), 0)


func test_appraised_box_shows_exact_curio_and_trades() -> void:
	var c := cc_make(13)
	var shown: Dictionary = c.appraised_offer()
	assert_false(shown.is_empty())
	assert_eq(c.appraised_offer(), shown, "offer is stable until bought")
	var got: Dictionary = c.buy_appraised()
	assert_eq(got["id"], shown["id"], "you get what you saw")
	assert_eq(int(c.tradeable[got["id"]]), 1)
	assert_false(c.appraised_offer().is_empty(), "next offer is ready")


func test_featured_rate_up() -> void:
	var tun := cc_commons_only()
	tun.set_value("featured_rate_up", 1.0)
	var c := cc_make(14, tun)
	assert_true(c.set_featured("curio_02"))
	assert_false(c.set_featured("nope"))
	c.add_boxes(5)
	for i: int in range(5):
		assert_eq(c.open_box()["id"], "curio_02")


func test_craft_from_free_shards_is_tradeable_locked_otherwise() -> void:
	var c := cc_make()
	c.shards_free = 10
	assert_eq(c.craft("curio_01"), {"id": "curio_01", "tradeable": true})
	c.shards_free = 5
	c.shards_locked = 5
	assert_eq(c.craft("curio_02"), {"id": "curio_02", "tradeable": false})
	assert_eq(c.shards_free + c.shards_locked, 0)
	assert_true(c.craft("curio_03").is_empty(), "no shards")


func test_granted_curio_trades_once() -> void:
	var c := cc_make()
	assert_true(c.grant("curio_01"))
	assert_true(c.take_tradeable("curio_01"))
	assert_false(c.take_tradeable("curio_01"))
	assert_false(c.owned.has("curio_01"))


func test_set_completion_claims_once() -> void:
	var c := cc_make()
	for id: Variant in c.sets()["parlor"]:
		c.grant(str(id))
	assert_eq(c.claim_completed_sets(), PackedStringArray(["parlor"]))
	assert_eq(c.claim_completed_sets(), PackedStringArray())


func test_won_run_earns_free_box() -> void:
	var c := cc_make()
	var run := RunState.new()
	run.start(1, Catalog.load_default(), Tuning.new())
	run.won = true
	assert_eq(c.reward_run(run), 1)
	assert_eq(c.free_boxes, 1)


func test_round_trip() -> void:
	var c := cc_make(9)
	c.add_boxes(5, true)
	c.open_box()
	c.appraised_offer()
	var d := cc_make(9)
	d.from_dict(c.to_dict())
	assert_eq(d.open_box(), c.open_box())
	assert_eq(d.appraised_offer(), c.appraised_offer())
