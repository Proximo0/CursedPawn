extends TestCase
## Wake types and night events in the 2D room (docs/full_game_plan.md steps 32-33).


func _room() -> ShopRoom2D:
	var room := ShopRoom2D.new()
	room.setup(null)
	return room


func test_wake_type_and_event_parsing() -> void:
	for t: String in RoomScenes.WAKE_TYPES:
		assert_eq(RoomScenes.wake_type_of({"wake_type": t}), t)
	assert_eq(RoomScenes.wake_type_of({"wake_type": "nonsense"}), "")
	assert_eq(RoomScenes.wake_type_of({}), "")
	assert_eq(RoomScenes.event_of({"night_event": "storm"}), "storm")
	assert_eq(RoomScenes.event_of({"event": "Full Moon"}), "full_moon")
	assert_eq(RoomScenes.event_of({"id": "blackout"}), "blackout")
	assert_eq(RoomScenes.event_of({"kind": "auction"}), "auction")
	assert_eq(RoomScenes.event_of({"night": 2}), "")


func test_lightning_is_a_bounded_pulse_that_comes_and_goes() -> void:
	var hit: int = 0
	var dark: int = 0
	for i: int in range(180):
		var f: float = RoomScenes.lightning(float(i) * 0.05)
		assert_true(f >= 0.0 and f <= 1.0)
		if f > 0.3:
			hit += 1
		if f == 0.0:
			dark += 1
	assert_true(hit > 3 and dark > 100)


func test_room_follows_night_events() -> void:
	var room: ShopRoom2D = _room()
	for ev: String in RoomScenes.NIGHT_EVENTS:
		room.apply_events([{"e": "night_start", "night": 2, "rent": 50, "night_event": ev}] as Array[Dictionary])
		assert_eq(room.night_event(), ev)
	room.apply_events([{"e": "night_end", "night": 2, "rent": 50, "cash": 10}] as Array[Dictionary])
	assert_eq(room.night_event(), "")
	room.set_night_event("storm")
	assert_eq(room.night_event(), "storm")
	room.set_night_event("bogus")
	assert_eq(room.night_event(), "")
	room.free()


func test_wake_event_picks_the_wake_type() -> void:
	for t: String in RoomScenes.WAKE_TYPES:
		var room: ShopRoom2D = _room()
		room.apply_events([{"e": "wake", "night": 2, "dread": 3.0, "broke": "", "closed": false, "wake_type": t}] as Array[Dictionary])
		assert_eq(room.wake_type(), t)
		assert_true(room.is_waking())
		room.free()
	var plain: ShopRoom2D = _room()
	plain.apply_events([{"e": "wake", "night": 2, "dread": 3.0, "broke": "", "closed": false}] as Array[Dictionary])
	assert_eq(plain.wake_type(), "")
	plain.free()


func test_every_scene_draws_on_a_canvas_without_error() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var ci := Node2D.new()
	ci.draw.connect(func() -> void:
		for t: String in RoomScenes.WAKE_TYPES:
			RoomScenes.draw_wake(ci, pal, Vector2(640.0, 360.0), t, 1.0, 1.0, 1, Vector2(300.0, 150.0))
		for ev: String in ["storm", "full_moon"]:
			RoomScenes.draw_window_event(ci, pal, ShopRoom2D.WINDOW_RECT, ev, 3.0, 0.5)
		RoomScenes.draw_podium(ci, pal, 2.0, 1.0))
	ci.notification(CanvasItem.NOTIFICATION_DRAW)
	ci.free()


func test_title_scene_helpers() -> void:
	var seen_shadow: int = 0
	for i: int in range(400):
		var t: float = float(i) * 0.1
		var k: float = RoomScenes.title_shadow_k(t)
		assert_true(k == -1.0 or (k >= 0.0 and k <= 1.0))
		if k >= 0.0:
			seen_shadow += 1
		assert_true(absf(RoomScenes.title_pan(t).x) <= 1.0 and absf(RoomScenes.title_pan(t).y) <= 1.0)
		var mp: Vector2 = RoomScenes.title_moth_pos(t)
		assert_true(mp.distance_to(RoomScenes.TITLE_LAMP) < 24.0, "moth stays at the lamp")
		assert_eq(mp, mp.round())
	assert_true(seen_shadow > 100 and seen_shadow < 300)
	var room: ShopRoom2D = _room()
	assert_false(room.title_mode())
	room.set_title_mode(true)
	assert_true(room.title_mode())
	room.free()


func test_walk_cycle_has_four_distinct_frames_of_the_same_size() -> void:
	var look: Dictionary = {"id": "haggler", "cloak": "#4b2a78", "eyes": "#ffd27a"}
	var base: Image = SpriteKit.customer_texture(look).get_image()
	var frames: Array[ImageTexture] = ArtContent.walk_frames(base)
	assert_eq(frames.size(), 4)
	var seen: Dictionary = {}
	for f: ImageTexture in frames:
		assert_eq(f.get_image().get_size(), base.get_size())
		seen[hash(f.get_image().get_data())] = true
	assert_eq(seen.size(), 4)


func test_arrival_rings_the_bell_lands_the_object_and_walks() -> void:
	var cat: Catalog = Catalog.load_default()
	var run := RunState.new()
	run.start(3, cat, Tuning.new())
	run.inventory.clear()
	var room := ShopRoom2D.new()
	room.setup(run)
	var rang: Array[int] = [0]
	var landed: Array[int] = [0]
	room.bell_rang.connect(func() -> void: rang[0] += 1)
	room.object_landed.connect(func() -> void: landed[0] += 1)
	var o: Dictionary = cat.objects[0]
	room.apply_events([{"e": "customer", "kind": "seller", "name": str(o["name"]), "category": str(o["category"]), "ask": 40, "tid": "widow", "line": "Hi."}] as Array[Dictionary])
	for i: int in range(120):
		room._process(0.05)
	assert_true(rang[0] >= 1, "bell rang")
	assert_true(landed[0] >= 1, "object landed")
	assert_eq(room.customer_state(), "here")
	room.free()


func test_a_sale_throws_coins_that_land() -> void:
	var room := ShopRoom2D.new()
	room.setup(null)
	var coins: Array[int] = [0]
	room.coin_landed.connect(func() -> void: coins[0] += 1)
	room.apply_events([{"e": "sold", "uid": 5, "name": "Hand mirror", "price": 70, "imposter": false}] as Array[Dictionary])
	for i: int in range(60):
		room._process(0.05)
	assert_eq(coins[0], 4)
	room.free()


func test_torch_flicker_is_a_seeded_curve() -> void:
	var lo: float = 9.0
	var hi: float = 0.0
	var differs: int = 0
	for i: int in range(300):
		var t: float = float(i) * 0.037
		var a: float = RoomScenes.torch_flicker(71, t, 0.2)
		assert_eq(a, RoomScenes.torch_flicker(71, t, 0.2))
		lo = minf(lo, a)
		hi = maxf(hi, a)
		if absf(a - RoomScenes.torch_flicker(1048, t, 0.2)) > 0.02:
			differs += 1
	assert_true(lo >= 0.35 and hi < 1.6, "bounded: %f %f" % [lo, hi])
	assert_true(hi - lo > 0.1, "it flickers")
	assert_true(differs > 100, "two torches do not flicker together")
	# more Dread, more violent
	var calm: float = 0.0
	var wild: float = 0.0
	for i: int in range(300):
		calm += absf(RoomScenes.torch_flicker(5, float(i) * 0.05, 0.0) - 1.0)
		wild += absf(RoomScenes.torch_flicker(5, float(i) * 0.05, 1.0) - 1.0)
	assert_true(wild > calm)


func test_dread_tints_the_flame_and_the_window_follows_the_night() -> void:
	var amber: Color = Color(1.0, 0.62, 0.28)
	assert_true(RoomScenes.dread_tint(amber, 0.0).is_equal_approx(amber))
	assert_true(RoomScenes.dread_tint(amber, 1.0).g < 0.45, "red by 1.0")
	assert_true(RoomScenes.dread_tint(amber, 0.5).g > amber.g, "sickly yellow-green halfway")
	var dusk: Dictionary = RoomScenes.window_phase(0.0)
	var night: Dictionary = RoomScenes.window_phase(0.5)
	var dawn: Dictionary = RoomScenes.window_phase(1.0)
	assert_true((dusk["light"] as Color).r > (dusk["light"] as Color).b, "dusk is warm")
	assert_true((night["light"] as Color).b > (night["light"] as Color).r, "night is cold blue")
	var d: Color = dawn["light"] as Color
	assert_true(absf(d.r - d.b) < 0.15, "pre-dawn is grey")
	assert_true(float(night["moon"]) > float(dusk["moon"]) and float(night["moon"]) > float(dawn["moon"]))
	assert_eq(int(dusk["tint"]), 12)
	assert_eq(int(dawn["tint"]), 14)
