extends TestCase

const RQ_REWARD: Dictionary = {"kind": "curio", "id": "curio_01"}


func rq_run(held: Array) -> RunState:
	var tun := Tuning.new()
	tun.set_value("request_chance", 0.0)
	var run := RunState.new()
	run.start(21, Catalog.load_default(), tun)
	run.inventory.assign(held)
	run.requests.assign([{"id": "r1", "who": "Mrs. Harrow", "tid": "collector", "want": {"category": "book", "cursed": false},
		"due": 1, "pay_mult": 2.0, "reward": RQ_REWARD, "called": false}])
	return run


func rq_book() -> Dictionary:
	return {"id": "b", "name": "Old book", "category": "book", "value": 100, "curse": "", "uid": 90, "est": 100, "tells": 0}


func rq_kinds(ev: Array[Dictionary]) -> Array:
	return ev.map(func(e: Dictionary) -> String: return str(e["e"]))


func test_new_request_is_announced() -> void:
	var tun := Tuning.new()
	tun.set_value("request_chance", 1.0)
	var run := RunState.new()
	var ev: Array[Dictionary] = run.start(2, Catalog.load_default(), tun)
	assert_true(rq_kinds(ev).has("request_new"))
	assert_eq(run.requests.size(), 1)
	var r: Dictionary = run.requests[0]
	assert_true(int(r["due"]) in [2, 3])
	assert_true(str(ev[-1]["want_text"]) != "")
	for i: int in range(30):
		if run.is_over():
			break
		run.apply({"t": "pass"})
		assert_true(run.requests.size() <= int(tun.requests_max), "never more than the maximum open")


func test_done_pays_and_banks_reward() -> void:
	var run := rq_run([rq_book()])
	var ev: Array[Dictionary] = run.apply({"t": "pass"})
	assert_true(rq_kinds(ev).has("request_due"))
	assert_true(run.customer.get("request", false))
	assert_eq(run.sellable().size(), 1)
	var cash: int = run.cash
	ev = run.apply({"t": "sell", "uid": 90})
	assert_eq(run.cash - cash, 200)
	assert_true(rq_kinds(ev).has("request_done"))
	assert_eq(run.requests.size(), 0)
	assert_eq(run.found, [RQ_REWARD] as Array[Dictionary])
	assert_eq(run.requests_done, 1)


func test_pass_fails() -> void:
	var run := rq_run([rq_book()])
	run.apply({"t": "pass"})
	var ev: Array[Dictionary] = run.apply({"t": "pass"})
	assert_true(rq_kinds(ev).has("request_failed"))
	assert_eq(run.requests.size(), 0)
	assert_eq(run.found.size(), 0)
	assert_eq(run.requests_failed, 1)


func test_nothing_to_sell_fails_at_once() -> void:
	var run := rq_run([])
	var ev: Array[Dictionary] = run.apply({"t": "pass"})
	assert_eq(rq_kinds(ev).filter(func(k: String) -> bool: return k.begins_with("request_")), ["request_due", "request_failed"])
	assert_false(run.customer.get("request", false))


func test_wrong_item_is_refused() -> void:
	var run := rq_run([rq_book(), {"id": "t", "name": "Toy", "category": "toy", "value": 50, "curse": "", "uid": 91, "est": 50, "tells": 0}])
	run.apply({"t": "pass"})
	assert_eq(run.apply({"t": "sell", "uid": 91})[0]["e"], "invalid")
	assert_eq(run.requests.size(), 1)


func test_cursed_want_and_snapshot() -> void:
	var run := rq_run([rq_book()])
	run.requests[0]["want"] = {"category": "", "cursed": true}
	run.apply({"t": "pass"})
	assert_eq(run.requests.size(), 0, "a clean book does not satisfy a cursed request")
	var b := RunState.new()
	var run2 := rq_run([rq_book()])
	b.restore(run2.snapshot(), Catalog.load_default())
	assert_eq(b.requests, run2.requests)
	assert_eq(b.state_hash(), run2.state_hash())
