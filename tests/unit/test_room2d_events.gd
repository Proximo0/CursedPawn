extends TestCase

const R2_EVENTS: Array = [
	{"e": "night_start", "night": 2, "rent": 60},
	{"e": "customer", "kind": "seller", "name": "Hand mirror", "ask": 40, "tid": "widow", "line": "Hello."},
	{"e": "customer", "kind": "buyer", "category": "toy"},
	{"e": "inspected", "tool": "uv", "tell": "glows", "estimate": {"mid": 50, "spread": 0.3}},
	{"e": "inspected", "tool": "scale", "tell": "", "estimate": {}},
	{"e": "inspected", "tool": "listen", "tell": "", "estimate": {}},
	{"e": "inspected", "tool": "touch", "tell": "", "estimate": {}},
	{"e": "inspected", "tool": "bogus", "tell": "", "estimate": {}},
	{"e": "counter", "offer": 10, "ask": 30, "patience": 2},
	{"e": "left", "offer": 5},
	{"e": "passed", "kind": "seller"},
	{"e": "wager", "card": "The Fool", "text": "x", "stake": 10, "payout": 20, "dread": 1.0},
	{"e": "wake", "night": 3, "dread": 4.5, "broke": "", "closed": true},
	{"e": "night_end", "night": 1, "rent": 40, "cash": 90},
	{"e": "run_lost", "night": 2, "cash": 5, "rent": 60},
	{"e": "run_won", "cash": 300},
	{"e": "invalid", "why": "tool uv"},
	{"e": "zzz"},
]


func _run_with(n: int) -> RunState:
	var cat: Catalog = Catalog.load_default()
	var run := RunState.new()
	run.start(3, cat, Tuning.new())
	run.inventory.clear()
	for i: int in range(n):
		var o: Dictionary = cat.objects[i % cat.objects.size()]
		run.inventory.append({"uid": 10 + i, "id": o["id"], "name": o["name"], "category": o["category"], "value": o["value"],
			"curse": "", "est": 1, "tells": 0})
	return run


func test_every_event_kind_is_accepted() -> void:
	var room := ShopRoom2D.new()
	room.setup(_run_with(3))
	for e: Dictionary in R2_EVENTS:
		room.apply_events([e] as Array[Dictionary])
	assert_eq(room.prop_count(), 3)
	room.free()


func test_events_without_setup_do_not_error() -> void:
	var room := ShopRoom2D.new()
	for e: Dictionary in R2_EVENTS:
		room.apply_events([e] as Array[Dictionary])
	room.free()


func test_prop_count_follows_inventory() -> void:
	for n: int in [0, 1, 6, 14, 40]:
		var room := ShopRoom2D.new()
		room.setup(_run_with(n))
		assert_eq(room.prop_count(), n, "n=%d" % n)
		room.free()


func test_bought_and_sold_change_props() -> void:
	var run: RunState = _run_with(2)
	var room := ShopRoom2D.new()
	room.setup(run)
	run.inventory.append({"uid": 99, "id": "x", "name": "Violin", "category": "instrument", "value": 1, "curse": "", "est": 1, "tells": 0})
	room.apply_events([{"e": "bought", "uid": 99, "name": "Violin", "price": 5}] as Array[Dictionary])
	assert_eq(room.prop_count(), 3)
	room.apply_events([{"e": "sold", "uid": 99, "name": "Violin", "price": 9, "imposter": false}] as Array[Dictionary])
	assert_eq(room.prop_count(), 2)
	room.free()


func test_wake_breaks_named_prop() -> void:
	var room := ShopRoom2D.new()
	room.setup(_run_with(3))
	var victim: String = room.prop_names()[0]
	room.apply_events([{"e": "wake", "night": 1, "dread": 3.0, "broke": victim, "closed": false}] as Array[Dictionary])
	assert_eq(room.prop_count(), 2)
	assert_true(room.is_waking())
	room.free()


func test_dither_flag_and_dread() -> void:
	var room := ShopRoom2D.new()
	assert_true(room.dither_enabled)
	room.dither_enabled = false
	assert_false(room.dither_enabled)
	room.set_dread(-3.0)
	assert_near(room.dread, 0.0)
	room.set_dread(2.0)
	assert_true(room.dread_norm() > 0.0)
	room.free()


func test_customer_arrives_speaks_and_leaves() -> void:
	var room := ShopRoom2D.new()
	room.setup(_run_with(1))
	room.apply_events([{"e": "customer", "kind": "seller", "name": "Violin", "ask": 4, "tid": "widow", "line": "Take it."}] as Array[Dictionary])
	assert_eq(room.customer_state(), "enter")
	room.settle_visuals()
	assert_eq(room.customer_state(), "here")
	assert_eq(room.bubble_text(), "Take it.")
	room.apply_events([{"e": "passed", "kind": "seller"}] as Array[Dictionary])
	room.settle_visuals()
	assert_eq(room.customer_state(), "none")
	assert_eq(room.bubble_text(), "")
	room.free()


func test_customer_dresses_as_their_type() -> void:
	var room := ShopRoom2D.new()
	room.setup(_run_with(0))
	room.apply_events([{"e": "customer", "kind": "buyer", "category": "toy", "tid": "priest"}] as Array[Dictionary])
	assert_eq(room.customer_look_id(), "priest")
	var tall: int = room.customer_height()
	room.apply_events([{"e": "customer", "kind": "buyer", "category": "toy", "tid": "haggler"}] as Array[Dictionary])
	assert_eq(room.customer_look_id(), "haggler")
	assert_true(room.customer_height() < tall, "haggler (0.85) is shorter than priest (1.1)")
	room.free()


func test_tool_effect_and_card_show() -> void:
	var room := ShopRoom2D.new()
	room.setup(_run_with(1))
	room.apply_events([{"e": "inspected", "tool": "listen", "tell": "", "estimate": {}}] as Array[Dictionary])
	assert_eq(room.fx_kind(), "listen")
	room.apply_events([{"e": "wager", "card": "The Fool", "stake": 1, "payout": 2, "dread": 0.0}] as Array[Dictionary])
	assert_true(room.has_card())
	room.apply_events([{"e": "customer", "kind": "buyer", "category": "toy", "tid": "priest"}] as Array[Dictionary])
	assert_false(room.has_card())
	room.free()


func test_selling_a_sliding_prop_does_not_touch_the_freed_body() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var room := ShopRoom2D.new()
	tree.root.add_child(room)
	var run := _run_with(0)
	room.setup(run)
	room.apply_events([{"e": "bought", "uid": 1, "name": run.catalog.objects[0]["name"], "price": 5}] as Array[Dictionary])
	room.apply_events([{"e": "sold", "uid": 1, "name": run.catalog.objects[0]["name"], "price": 9, "imposter": false}] as Array[Dictionary])
	room._update_slides(0.1)
	assert_eq(room._slides.size(), 0, "freed slide dropped without a cast error")
	room.free()
