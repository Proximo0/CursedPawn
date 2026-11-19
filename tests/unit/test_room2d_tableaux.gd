extends TestCase
## Ending tableaux (step 34), title scene (step 35) and store art helpers (step 38): size, palette, determinism.


func _palette_ok(img: Image) -> bool:
	var pal: PackedColorArray = RoomPalette.colors()
	var seen: Dictionary = {}
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var key: int = c.to_rgba32()
			if seen.has(key):
				continue
			var hit: bool = false
			for p: Color in pal:
				if absf(p.r - c.r) < 0.004 and absf(p.g - c.g) < 0.004 and absf(p.b - c.b) < 0.004:
					hit = true
					break
			if not hit or c.a < 0.99:
				return false
			seen[key] = true
	return true


func test_each_ending_has_a_full_screen_palette_only_tableau() -> void:
	var seen: Dictionary = {}
	for id: String in EndingArt.IDS:
		var img: Image = EndingArt.tableau_image(id)
		assert_eq(img.get_size(), Vector2i(640, 360), id)
		assert_true(_palette_ok(img), id + " palette")
		assert_eq(img.get_pixel(320, 180).a, 1.0, id + " opaque")
		var key: int = hash(img.get_data())
		assert_false(seen.has(key), id + " identical to " + str(seen.get(key, "")))
		seen[key] = id


func test_ending_ids_resolve_by_keyword_and_default() -> void:
	assert_eq(EndingArt.id_for("debt_free"), "debt_free")
	assert_eq(EndingArt.id_for("the_collector_satisfied"), "collector")
	assert_eq(EndingArt.id_for("regulars_arcs"), "regulars")
	assert_eq(EndingArt.id_for("cursed_beyond_saving"), "cursed")
	assert_eq(EndingArt.id_for("run_lost"), "evicted")
	assert_eq(EndingArt.id_for("zzz"), "debt_free")


func test_tableau_is_deterministic() -> void:
	assert_true(EndingArt.tableau_image("cursed").get_data() == EndingArt.tableau_image("cursed").get_data())


func test_store_sizes_are_steams() -> void:
	assert_eq(StoreArt.size_of("header"), Vector2i(920, 430))
	assert_eq(StoreArt.size_of("small"), Vector2i(462, 174))
	assert_eq(StoreArt.size_of("main"), Vector2i(1232, 706))
	assert_eq(StoreArt.size_of("vertical"), Vector2i(748, 896))
	assert_eq(StoreArt.size_of("library"), Vector2i(600, 900))
	assert_eq(StoreArt.size_of("hero"), Vector2i(3840, 1240))
	assert_eq(StoreArt.SIZES.size(), 7)


func test_store_text_and_logo_are_palette_only_and_fit() -> void:
	var s: int = StoreArt.fit_scale(StoreArt.TITLE, 500)
	assert_true(s >= 2 and UiPixelFont.ui_display_width(StoreArt.TITLE, s) <= 500)
	var t: Image = StoreArt.text_image(StoreArt.TITLE, 3)
	assert_true(_palette_ok(t))
	var lit: int = 0
	for y: int in range(t.get_height()):
		for x: int in range(t.get_width()):
			if t.get_pixel(x, y).a > 0.5:
				lit += 1
	assert_true(lit > 400, "text has pixels")
	var logo: Image = StoreArt.logo_image(600)
	assert_true(logo.get_width() <= 600 and _palette_ok(logo))


func test_store_cover_crops_whole_pixel_upscales() -> void:
	var src: Image = Image.create_empty(64, 36, false, Image.FORMAT_RGBA8)
	src.fill(Color.WHITE)
	src.set_pixel(10, 10, Color.BLACK)
	var out: Image = StoreArt.cover(src, 100, 50, Vector2(0.5, 0.5))
	assert_eq(out.get_size(), Vector2i(100, 50))
	assert_eq(out.get_pixel(50, 25).a, 1.0)


func test_small_capsule_composes_on_a_fake_shot() -> void:
	var shot: Image = Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)
	shot.fill(RoomPalette.colors()[2])
	var fig: Image = SpriteKit.customer_texture({"id": "collector"}).get_image()
	var img: Image = StoreArt.compose("small", {"room": shot, "dread": shot}, fig)
	assert_eq(img.get_size(), Vector2i(462, 174))
	assert_true(_palette_ok(img))
	var logo: Image = StoreArt.compose("logo", {}, fig)
	assert_eq(logo.get_size(), Vector2i(1280, 720))
	assert_eq(logo.get_pixel(2, 2).a, 0.0, "the logo is transparent")
