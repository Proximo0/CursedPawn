extends TestCase


func rst_make() -> RelicStore:
	return RelicStore.create(CurioCollection.create(1, Tuning.new()))


func test_shop_closed_until_age_checked() -> void:
	var s := rst_make()
	assert_true(s.quote("sealed_1").is_empty())
	assert_true(s.fulfill("sealed_1", "p1").is_empty())
	s.set_age(17, true)
	assert_false(s.is_open(), "under 18, even accepting terms")
	s.set_age(30)
	assert_false(s.is_open(), "terms not accepted")
	s.set_age(30, true)
	assert_true(s.is_open())
	assert_eq(s.terms_accepted, RelicStore.TERMS_VERSION)


func test_sealed_quote_shows_dollars_odds_and_lock() -> void:
	var s := rst_make()
	s.set_age(30, true)
	var q: Dictionary = s.quote("sealed_10")
	assert_eq(q["price"], "$17.99")
	assert_true(q.has("odds"))
	assert_false(q["tradeable"])
	assert_eq(q["pity_left"], 30)


func test_sealed_fulfill_adds_paid_boxes() -> void:
	var s := rst_make()
	s.set_age(30, true)
	s.fulfill("sealed_10", "p1")
	assert_eq(s.collection.paid_boxes, 10)
	assert_eq(s.spent_cents(), 1799)


func test_scried_delivers_what_the_quote_showed() -> void:
	var s := rst_make()
	s.set_age(30, true)
	var shown: Dictionary = s.quote("scried_1")["shows"]
	var entry: Dictionary = s.fulfill("scried_1", "p2")
	assert_eq(entry["delivered"][0]["id"], shown["id"])
	assert_eq(int(s.collection.tradeable[shown["id"]]), 1)


func test_featured_needs_a_featured_curio() -> void:
	var s := rst_make()
	s.set_age(30, true)
	assert_true(s.fulfill("bound_relic", "p3").is_empty())
	s.collection.set_featured("curio_10")
	assert_eq(s.fulfill("bound_relic", "p3")["delivered"][0]["id"], "curio_10")


func test_refund_takes_back_unopened_boxes_and_keeps_shop_open() -> void:
	var s := rst_make()
	s.set_age(30, true)
	var e: Dictionary = s.fulfill("sealed_10", "p4")
	s.collection.open_box()
	assert_true(s.refund(int(e["n"])))
	assert_eq(s.collection.paid_boxes, 0)
	assert_false(s.refund(int(e["n"])), "only once")
	assert_true(s.is_open(), "no lockout")
	assert_eq(s.spent_cents(), 0)
