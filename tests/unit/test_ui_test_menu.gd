extends TestCase
## The test menu: tile list, paging, the throwaway profile and every tile opening.

const TM_SCENE: String = "res://game/ui/shop_game.tscn"


func tm_game() -> ShopGame:
	var g: ShopGame = (load(TM_SCENE) as PackedScene).instantiate() as ShopGame
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	return g


func test_tiles_are_unique_and_grouped() -> void:
	var seen: Dictionary = {}
	for t: Dictionary in TestScenes.tiles():
		assert_false(seen.has(t["id"]), "duplicate " + str(t["id"]))
		seen[t["id"]] = true
		assert_true(TestScenes.GROUPS.has(str(t["group"])), "group of " + str(t["id"]))
		assert_true(UiPixelFont.ui_width(str(t["label"])) <= int(TestMenu.TILE_W) - 8, "label fits " + str(t["id"]))
	assert_true(seen.size() >= 40, "the plan's list")


func test_pages_hold_every_tile_once() -> void:
	var count: int = 0
	for pg: Array in TestMenu.tm_pages(TestScenes.tiles()):
		var rows: int = 0
		for grp: Dictionary in pg:
			count += (grp["ids"] as Array).size()
			rows += 1 + int(ceil(float((grp["ids"] as Array).size()) / float(TestMenu.COLS)))
		assert_true(rows <= TestMenu.MAX_ROWS, "page fits")
	assert_eq(count, TestScenes.tiles().size())


func test_title_offers_the_menu_only_when_asked() -> void:
	var on: Array[Dictionary] = TitleScreen.ts_entries(false, false, false, 0, false, true, false, true)
	var off: Array[Dictionary] = TitleScreen.ts_entries(false, false, false, 0, false, true, false, false)
	assert_eq(str(on[on.size() - 2]["id"]), "test")
	assert_eq(on.size(), off.size() + 1)


func test_every_tile_opens_without_touching_the_profile() -> void:
	var g: ShopGame = tm_game()
	g.open_test_menu()
	assert_true(g._relics.no_save, "throwaway profile")
	var failed: PackedStringArray = PackedStringArray()
	for t: Dictionary in TestScenes.tiles():
		for scares: int in range(2):
			g.test_menu.scares = scares
			g.run_test_tile(str(t["id"]))
			if not g.test_active:
				failed.append(str(t["id"]))
			g.exit_test_tile()
	assert_eq(failed, PackedStringArray(), "tiles that did not open")
	g.leave_test_menu()
	assert_false(g._relics.no_save, "profile back")
	g.queue_free()


func test_regular_tiles_follow_the_menu_choice() -> void:
	var g: ShopGame = tm_game()
	g.open_test_menu()
	for i: int in range(TestScenes.REGULAR_IDS.size()):
		g.test_menu.regular = i
		g.test_menu.chapter = 1
		g.run_test_tile("regular")
		assert_eq(str(g.run.regular.get("id", "")), TestScenes.REGULAR_IDS[i])
		assert_eq(int(g.run.regular.get("chapter", -1)), 1)
	g.leave_test_menu()
	g.queue_free()


func test_dread_slider_moves_dread() -> void:
	var g: ShopGame = tm_game()
	g.open_test_menu()
	g.run_test_tile("dread")
	g.test_set_dread(0.5)
	assert_near(g.run.dread, 0.5 * ShopGame.TEST_DREAD_SPAN * g.run.tuning.wake_threshold)
	assert_true(g.test_slider_click(Vector2(TestOverlay.BAR.end.x, TestOverlay.BAR.position.y + 2.0)))
	assert_false(g.test_slider_click(Vector2(5.0, 300.0)))
	g.leave_test_menu()
	g.queue_free()


func test_navigation_reaches_other_rows() -> void:
	var m := TestMenu.new()
	m.focus_id = m.tm_page_ids()[0]
	m.ts_key(KEY_DOWN)
	assert_true(m.focus_id != m.tm_page_ids()[0], "moved down")
	m.free()


func test_wake_tiles_fire_their_wake_type() -> void:
	for w: String in TestScenes.WAKE_TYPES:
		var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
		(Engine.get_main_loop() as SceneTree).root.add_child(g)
		g.test_begin(5)
		TestScenes.build("wake_" + w, g, {})
		assert_true(g.room != null)
		if g.room != null:
			assert_eq(g.room.wake_type(), w, "wake tile " + w)
		g.queue_free()
