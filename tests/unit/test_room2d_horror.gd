extends TestCase
## The horror-polish layer of the 2D room: bubble, particles, normal maps, scare level, wake beat, cursed overlay.


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


func test_view_is_640_by_360_and_scare_defaults_full() -> void:
	assert_eq(ShopRoom2D.VIEW_SIZE, Vector2i(640, 360))
	var room := ShopRoom2D.new()
	assert_eq(room.scare_level, 1)
	room.free()


func test_bubble_types_out_and_blips() -> void:
	var b := RoomBubble.new()
	var blips: Array[float] = []
	b.blip.connect(func(p: float) -> void: blips.append(p))
	b.open("Don't ask where it's from.", Vector2(300.0, 120.0), 640.0)
	assert_true(b.is_speaking())
	assert_eq(b.typed_count(), 0)
	for i: int in range(30):
		b.advance(1.0 / 60.0)
	assert_true(b.typed_count() > 5 and b.typed_count() < 26, "typed %d" % b.typed_count())
	assert_true(blips.size() > 0)
	b.finish_typing()
	assert_eq(b.shown_text(), "Don't ask where it's from.")
	b.close()
	assert_eq(b.shown_text(), "", "fraying bubbles no longer count as speaking")
	for i: int in range(60):
		b.advance(1.0 / 60.0)
	assert_false(b.is_open())
	b.free()


func test_bubble_box_stays_inside_the_room() -> void:
	var b := RoomBubble.new()
	b.open("A rather long line that must wrap onto several rows without leaving the screen.", Vector2(630.0, 140.0), 640.0)
	var r: Rect2 = b.box_rect()
	assert_true(r.position.x >= 6.0 and r.end.x <= 634.0, "box %s" % str(r))
	b.free()


func test_fx_pool_is_capped_and_expires() -> void:
	var fx := RoomFx.new()
	for k: String in ["sparkle", "smoke", "trail", "dust", "ash", "bogus"]:
		fx.emit(k, Vector2(10.0, 10.0), 100)
	assert_true(fx.count() <= RoomFx.MAX_PARTICLES)
	for i: int in range(200):
		fx.update(0.02)
	assert_eq(fx.count(), 0)


func test_normal_map_is_flat_on_flat_art_and_tilted_at_edges() -> void:
	var img: Image = Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.0))
	for y: int in range(2, 10):
		for x: int in range(2, 10):
			img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 1.0))
	var n: Image = RoomNormals.normal_image(img, 1.5, false)
	var mid: Color = n.get_pixel(5, 5)
	assert_near(mid.r, 0.5, 0.05)
	assert_near(mid.g, 0.5, 0.05)
	assert_true(n.get_pixel(2, 3).r < 0.45, "left edge leans left")


func test_wake_opens_with_a_blackout_beat_and_gentle_has_no_strobe() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var room := ShopRoom2D.new()
	tree.root.add_child(room)
	room.setup(_run_with(3))
	room.wake(5)
	var full_peak: float = 0.0
	var full_off: int = 0
	for t: int in range(ShopRoom2D.BEAT_TICKS):
		room._wake_step()
		assert_near(room.light_level(), 0.0, 0.001)
		full_peak = maxf(full_peak, room._flash)
		if t >= ShopRoom2D.FLASH_FROM and t < ShopRoom2D.FLASH_TO and room._flash == 0.0:
			full_off += 1
	assert_near(full_peak, 1.0, 0.001)
	assert_true(full_off > 0, "full scares strobe")
	room.scare_level = 0
	room.wake(5)
	var gentle_peak: float = 0.0
	for t: int in range(ShopRoom2D.BEAT_TICKS):
		room._wake_step()
		gentle_peak = maxf(gentle_peak, room._flash)
	assert_true(gentle_peak > 0.0 and gentle_peak < 0.5, "gentle shows it dimly: %f" % gentle_peak)
	room.free()


func test_cursed_overlay_appears_only_for_a_found_tell_on_the_seller() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var room := ShopRoom2D.new()
	tree.root.add_child(room)
	room.setup(_run_with(1))
	room.apply_events([{"e": "customer", "kind": "seller", "name": "Violin", "ask": 4, "tid": "widow", "line": "x"}] as Array[Dictionary])
	room.settle_visuals()
	room.apply_events([{"e": "inspected", "tool": "uv", "tell": "", "estimate": {}}] as Array[Dictionary])
	assert_false(room._overlay_on)
	room.apply_events([{"e": "inspected", "tool": "uv", "tell": "glows", "estimate": {}}] as Array[Dictionary])
	assert_true(room._overlay_on)
	room.apply_events([{"e": "passed", "kind": "seller"}] as Array[Dictionary])
	room.settle_visuals()
	assert_false(room._overlay_on)
	room.free()


func test_dread_stages_and_sale_sparkles_do_not_error() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var room := ShopRoom2D.new()
	tree.root.add_child(room)
	var run: RunState = _run_with(4)
	room.setup(run)
	for d: float in [0.0, 0.3, 0.5, 0.7, 0.9, 1.1]:
		room.set_dread(d * Tuning.shared().wake_threshold)
		for i: int in range(5):
			room._process(0.05)
	room.apply_events([{"e": "sold", "uid": 10, "name": run.inventory[0]["name"], "price": 9, "imposter": false}] as Array[Dictionary])
	assert_true(room._fx_sys.count() > 0, "coin sparkles")
	room.free()


func test_screen_fit_matches_the_hud_grid_rules() -> void:
	assert_near(ShopRoom2D.fit_scale(Vector2(1280.0, 720.0)), 2.0)
	assert_near(ShopRoom2D.fit_scale(Vector2(1920.0, 1080.0)), 3.0)
	assert_near(ShopRoom2D.fit_scale(Vector2(1000.0, 560.0)), 560.0 / 360.0, 0.001)  # 1x would keep under 80% of the fit
	assert_eq(ShopRoom2D.fit_rect(Vector2(1280.0, 720.0)), Rect2(0.0, 0.0, 1280.0, 720.0))
