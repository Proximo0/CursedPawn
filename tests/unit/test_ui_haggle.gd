extends TestCase
## The haggle candle and mood chip.


func test_patience_candle() -> void:
	assert_near(UiHaggle.patience_frac(3, 3), 1.0)
	assert_near(UiHaggle.patience_frac(0, 3), 0.0)
	assert_near(UiHaggle.patience_frac(9, 3), 1.0)
	assert_eq(UiHaggle.flame_for(1.0), 0)
	assert_eq(UiHaggle.flame_for(0.5), 1)
	assert_eq(UiHaggle.flame_for(0.2), 2)
	assert_eq(UiHaggle.flame_for(0.0), -1)


func test_mood_is_a_secret_until_the_first_counter() -> void:
	assert_eq(UiHaggle.mood_chip("nervous", false), "")
	assert_eq(UiHaggle.mood_chip("nervous", true), "MOOD: NERVOUS")
	assert_eq(UiHaggle.mood_chip("weird", true), "")
	assert_eq(UiHaggle.counter_line({"tell": "They flinch."}), "They flinch.")
	assert_eq(UiHaggle.counter_line({}), "")


func test_game_tracks_mood_and_patience() -> void:
	var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	g.test_feed([{"e": "customer", "kind": "seller", "name": "x", "ask": 9, "type": "t", "tid": "t", "line": "", "mood": "greedy", "mood_line": "A gold tooth."}] as Array[Dictionary])
	assert_eq(g.mood, "greedy")
	assert_false(g.mood_known)
	assert_true("\n".join(g.log_lines).contains("gold tooth"))
	g.test_feed([{"e": "counter", "offer": 3, "ask": 8, "patience": 2, "mood": "greedy", "tell": "A finger taps."}] as Array[Dictionary])
	assert_true(g.mood_known)
	assert_true("\n".join(g.log_lines).contains("finger taps"))
	g.queue_free()


func _buyer_game() -> ShopGame:
	var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	g.test_begin(5)
	return g


func test_buyer_offer_commands_and_bounds() -> void:
	var g: ShopGame = _buyer_game()
	var r: RunState = g.run
	r.customer = {"kind": RunState.BUYER, "category": "toy", "offer": {"uid": 5, "price": 10}}
	assert_true(ShopGame.buyer_offering(r))
	assert_eq(ShopGame.ui_key_command(KEY_ENTER, r, 14, -1).get("t", ""), "accept")
	var c: Dictionary = ShopGame.ui_key_command(KEY_C, r, 14, -1)
	assert_eq(c.get("t", ""), "counter")
	assert_eq(int(c.get("amount", 0)), 14)
	assert_eq(ShopGame.clamp_offer(r, 3), 11)
	assert_eq(ShopGame.clamp_offer(r, 99), 30)
	r.customer["offer"] = {}
	assert_false(ShopGame.buyer_offering(r))
	assert_eq(ShopGame.ui_key_command(KEY_C, r, 14, -1).size(), 0)
	g.queue_free()


func test_buyer_offer_event_sets_counter_box_and_tell() -> void:
	var g: ShopGame = _buyer_game()
	g.run.customer = {"kind": RunState.BUYER, "category": "toy", "patience": 3, "offer": {"uid": 5, "price": 20}}
	g.test_feed([{"e": "buyer_offer", "uid": 5, "name": "Doll", "offer": 20, "patience": 3, "mood": "stingy", "tell": "They sigh.", "counter": true}] as Array[Dictionary])
	assert_eq(g.offer_amount, 25)
	assert_true(g.mood_known)
	assert_true("\n".join(g.log_lines).contains("They sigh."))
	g.queue_free()


func test_formerly_silent_events_have_log_lines() -> void:
	for ev: String in ["curse_copied", "curse_shift", "whispered_away", "debt_taken", "buyer_offer"]:
		var line: String = ShopGame.ui_event_line({"e": ev, "from": "a", "name": "b", "to": "c", "who": "w", "amount": 3, "offer": 4})
		assert_true(line != "" and not line.begins_with("Unknown"), ev)
	assert_true(ShopGame.FEEDBACK_SOUNDS.has("debt_taken"))
