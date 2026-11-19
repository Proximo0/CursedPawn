extends TestCase
## The BUYER OFFERS test tile really leaves an ordinary buyer with an offer on the table.


func test_buyer_offer_tile_state() -> void:
	var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	g.test_begin(5)
	TestScenes.build("buyer_offer", g, {})
	assert_eq(str(g.run.customer.get("kind", "")), RunState.BUYER)
	assert_true(ShopGame.buyer_offering(g.run))
	assert_true(g.offer_amount > int((g.run.customer["offer"] as Dictionary)["price"]))
	g.queue_free()
