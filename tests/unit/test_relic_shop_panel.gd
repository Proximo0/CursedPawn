extends TestCase


func test_odds_text() -> void:
	assert_eq(RelicShopPanel.rsp_odds_text({"common": 0.7, "rare": 0.25, "legendary": 0.05}),
		"Common 70% · Rare 25% · Legendary 5%")


func test_rarity_colors_differ() -> void:
	assert_true(RelicShopPanel.rsp_rarity_color("rare") != RelicShopPanel.rsp_rarity_color("legendary"))
	assert_true(RelicShopPanel.rsp_rarity_color("common") != RelicShopPanel.rsp_rarity_color("rare"))


func test_quote_text_sealed_and_scried() -> void:
	var store := RelicStore.create(CurioCollection.create(1, Tuning.new()))
	assert_eq(RelicShopPanel.rsp_quote_text({}), RelicShopPanel.CLOSED_TEXT)
	store.set_age(30, true)
	var sealed: String = RelicShopPanel.rsp_quote_text(store.quote("sealed_1"))
	assert_true(sealed.contains("$1.99") and sealed.contains("Common") and sealed.contains("cannot be traded"))
	assert_true(sealed.contains("DEBUG: no real payment"))
	var scried: String = RelicShopPanel.rsp_quote_text(store.quote("scried_1"))
	assert_true(scried.contains("Contains:") and scried.contains("Tradeable"))


func test_reveal_text() -> void:
	var t: String = RelicShopPanel.rsp_reveal_text({"rarity": "rare", "name": "Cup", "new": false, "shards": 5,
		"tradeable": false, "pity": false})
	assert_true(t.contains("Duplicate") and t.contains("+5 shards") and t.contains("Bound"))
	assert_true(RelicShopPanel.rsp_set_done_text("attic").contains("attic shop theme unlocked"))
	assert_true(RelicShopPanel.rsp_cell_text({"name": "A", "rarity": "rare"}, 2, 1).contains("x2 (1 tradeable)"))
