extends TestCase

const DEFS: Array = [
	{"id": "a", "name": "Alpha", "text": "First.", "cost": 4, "max_rank": 2},
	{"id": "b", "name": "Beta", "text": "Second.", "cost": [3, 6, 9], "max_rank": 3},
]


func _altar(have: int, ranks: Dictionary) -> UiAltar:
	UiAltar.force_defs = DEFS
	var a := UiAltar.new()
	a.ecto = have
	a.ranks = ranks
	a.buy_fn = func(_id: String) -> String: return "ok"
	return a


func _end(a: UiAltar) -> void:
	a.free()
	UiAltar.force_defs = []


func test_cost_and_state() -> void:
	assert_eq(UiAltar.cost_of(DEFS[0], 0), 4)
	assert_eq(UiAltar.cost_of(DEFS[1], 1), 6)
	assert_eq(UiAltar.cost_of(DEFS[1], 9), 9, "past the list: the last cost")
	assert_eq(UiAltar.card_state(DEFS[0], 0, 4), "buy")
	assert_eq(UiAltar.card_state(DEFS[0], 0, 3), "dear")
	assert_eq(UiAltar.card_state(DEFS[0], 2, 99), "maxed")


func test_buy_spends_and_ranks() -> void:
	var a: UiAltar = _altar(10, {})
	assert_eq(a.try_buy("a"), "ok")
	assert_eq(a.ecto, 6)
	assert_eq(int(a.ranks["a"]), 1)
	assert_eq(a.try_buy("b"), "ok")
	assert_eq(a.ecto, 3)
	assert_eq(a.try_buy("b"), "dear", "rank 2 of b costs 6")
	assert_eq(a.ecto, 3)
	_end(a)


func test_maxed_and_unknown_refuse() -> void:
	var a: UiAltar = _altar(50, {"a": 2})
	assert_eq(a.try_buy("a"), "maxed")
	assert_eq(a.try_buy("zzz"), "unknown")
	assert_eq(a.ecto, 50)
	_end(a)


func test_a_refused_logic_buy_changes_nothing() -> void:
	var a: UiAltar = _altar(10, {})
	a.buy_fn = func(_id: String) -> Dictionary: return {"ok": false, "why": "not now"}
	assert_eq(a.try_buy("a"), "not now")
	assert_eq(a.ecto, 10)
	_end(a)


func test_buy_result_shapes() -> void:
	assert_true(UiAltar.buy_ok("ok"))
	assert_true(UiAltar.buy_ok(true))
	assert_true(UiAltar.buy_ok({"ok": true}))
	assert_false(UiAltar.buy_ok("dear"))
	assert_false(UiAltar.buy_ok({"ok": false}))


func test_store_fields_are_read_when_present() -> void:
	assert_eq(UiAltar.store_ecto(null), 0)
	assert_eq(UiAltar.store_ranks(null), {})
	var o := Object.new()
	assert_eq(UiAltar.store_ecto(o), 0)
	o.free()


func test_menu_ids_and_card_grid() -> void:
	UiAltar.force_defs = DEFS
	var a := UiAltar.new()
	assert_eq(a.ts_menu_ids(), ["up:a", "up:b", "back"] as Array[String])
	_end(a)
	assert_true(UiAltar.card_rect(4).position.y > UiAltar.card_rect(0).position.y)
	assert_eq(UiAltar.card_rect(1).position.x - UiAltar.card_rect(0).end.x, UiAltar.CARD_GAP)
	assert_true(UiAltar.card_rect(7).end.x <= ShopGame.VIEW.x and UiAltar.card_rect(7).end.y < UiAltar.BACK_RECT.position.y)


func test_placeholder_icon_is_16() -> void:
	assert_eq(UiAltar.placeholder_icon("shelf").get_size(), Vector2(16, 16))
