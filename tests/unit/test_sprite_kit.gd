extends TestCase

const OBJECTS_PATH: String = "res://game/data/objects.json"
const CUSTOMERS_PATH: String = "res://game/data/customers.json"


func _rows(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed as Array


func _palette_ok(img: Image) -> bool:
	var pal: PackedColorArray = RoomPalette.colors()
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			if c.a < 0.99:
				return false
			var hit: bool = false
			for p: Color in pal:
				if absf(p.r - c.r) < 0.004 and absf(p.g - c.g) < 0.004 and absf(p.b - c.b) < 0.004:
					hit = true
					break
			if not hit:
				return false
	return true


func _opaque_count(img: Image) -> int:
	var n: int = 0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


func test_every_object_is_drawn_small_transparent_and_palette_only() -> void:
	var seen: Dictionary = {}
	for row: Dictionary in _rows(OBJECTS_PATH):
		var id: String = str(row["id"])
		var img: Image = SpriteKit.object_texture(id, str(row["category"])).get_image()
		assert_true(img.get_width() <= 40 and img.get_height() <= 40, id + " size")
		assert_true(_opaque_count(img) > 60, id + " too empty")
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(img.get_width() - 1, 0), Vector2i(0, img.get_height() - 1),
				Vector2i(img.get_width() - 1, img.get_height() - 1)]:
			assert_true(img.get_pixelv(corner).a < 0.01, id + " corner")
		assert_true(_palette_ok(img), id + " palette")
		var key: int = hash(img.get_data())
		assert_false(seen.has(key), id + " identical to " + str(seen.get(key, "")))
		seen[key] = id


func test_same_id_same_bytes() -> void:
	for id: String in ["music_box", "violin", "taxidermy_owl", "no_such_id"]:
		var a: Image = SpriteKit.object_texture(id, "relic").get_image()
		var b: Image = SpriteKit.object_texture(id, "relic").get_image()
		assert_true(a.get_data() == b.get_data(), id)


func test_unknown_id_uses_category_fallback() -> void:
	var cats: Array[String] = ["toy", "jewelry", "instrument", "book", "relic", "other"]
	var seen: Dictionary = {}
	for c: String in cats:
		var img: Image = SpriteKit.object_texture("zz_unknown", c).get_image()
		assert_true(_opaque_count(img) > 40, c)
		assert_true(_palette_ok(img), c)
		seen[hash(img.get_data())] = true
	assert_eq(seen.size(), cats.size())


func test_customers_follow_height_and_use_palette() -> void:
	for row: Dictionary in _rows(CUSTOMERS_PATH):
		var img: Image = SpriteKit.customer_texture(row).get_image()
		assert_eq(img.get_width(), 64)
		assert_eq(img.get_height(), roundi(96.0 * clampf(float(row["height"]), 0.7, 1.3)), str(row["id"]))
		assert_true(_palette_ok(img), str(row["id"]))
		assert_true(img.get_pixel(0, 0).a < 0.01)
	var a: Image = SpriteKit.customer_texture({"cloak": "#4b2a78", "eyes": "#c58cff", "height": 1.0}).get_image()
	var b: Image = SpriteKit.customer_texture({"cloak": "#4a1420", "eyes": "#ffd27a", "height": 1.0}).get_image()
	assert_false(a.get_data() == b.get_data())


func test_tools_cards_and_tiles() -> void:
	var seen: Dictionary = {}
	for t: String in ["uv", "scale", "listen", "touch"]:
		var img: Image = SpriteKit.tool_texture(t).get_image()
		assert_true(_opaque_count(img) > 40 and _palette_ok(img), t)
		seen[hash(img.get_data())] = true
	assert_eq(seen.size(), 4)
	seen.clear()
	for n: String in ["The Sun", "Wheel of Fortune", "The Fool", "Death", "The Tower", "Mystery"]:
		var face: Image = SpriteKit.card_texture(n, true).get_image()
		assert_eq(face.get_size(), Vector2i(24, 40))
		assert_true(_palette_ok(face), n)
		seen[hash(face.get_data())] = true
	assert_eq(seen.size(), 6)
	var back: Image = SpriteKit.card_texture("The Sun", false).get_image()
	assert_true(_palette_ok(back))
	assert_false(back.get_data() == SpriteKit.card_texture("The Sun", true).get_image().get_data())
	for k: String in ["wall", "floor", "shelf", "counter", "door"]:
		var tile: Image = SpriteKit.tile_texture(k).get_image()
		assert_true(tile.get_width() in [16, 32] and tile.get_height() in [16, 32, 48], k)
		assert_true(_palette_ok(tile), k)


func test_customer_frames_are_same_size_distinct_and_palette_only() -> void:
	for row: Dictionary in _rows(CUSTOMERS_PATH):
		var frames: Array[ImageTexture] = SpriteKit.customer_frames(row)
		assert_eq(frames.size(), 4, str(row["id"]))
		var base: Image = SpriteKit.customer_texture(row).get_image()
		var seen: Dictionary = {}
		for f: ImageTexture in frames:
			var img: Image = f.get_image()
			assert_eq(img.get_size(), base.get_size(), str(row["id"]))
			assert_true(_palette_ok(img), str(row["id"]))
			assert_true(_opaque_count(img) > 900, str(row["id"]))
			seen[hash(img.get_data())] = true
		assert_eq(seen.size(), 4, str(row["id"]) + " frames must differ")
		assert_true(frames[0].get_image().get_data() == base.get_data(), "frame 0 is the still")
	var eyes: Dictionary = {}
	for row: Dictionary in _rows(CUSTOMERS_PATH):
		var look: Dictionary = row.duplicate()
		look["cloak"] = "#4b2a78"
		look["eyes"] = "#ffd27a"
		look["height"] = 1.0
		eyes[hash(SpriteKit.customer_texture(look).get_image().get_data())] = true
	assert_true(eyes.size() >= 8, "eye styles should differ per customer type")


func test_cursed_overlays_stay_inside_the_object() -> void:
	var seen: Dictionary = {}
	for row: Dictionary in _rows(OBJECTS_PATH):
		var id: String = str(row["id"])
		var base: Image = SpriteKit.object_texture(id, str(row["category"])).get_image()
		var ov: Image = SpriteKit.object_cursed_overlay(id).get_image()
		assert_eq(ov.get_size(), base.get_size(), id)
		assert_true(_palette_ok(ov), id)
		var n: int = _opaque_count(ov)
		assert_true(n >= 3 and n < 120, id + " overlay should be faint but present: " + str(n))
		for y: int in range(ov.get_height()):
			for x: int in range(ov.get_width()):
				if ov.get_pixel(x, y).a > 0.5:
					assert_true(base.get_pixel(x, y).a > 0.5, id + " overlay outside object")
		seen[hash(ov.get_data())] = true
		assert_true(ov.get_data() == SpriteKit.object_cursed_overlay(id).get_image().get_data(), id + " deterministic")
	assert_true(seen.size() >= 30, "distinct overlays: " + str(seen.size()))


func test_horror_props_have_documented_sizes() -> void:
	var sizes: Dictionary = {"eyes": Vector2i(16, 6), "portrait": Vector2i(24, 32), "silhouette": Vector2i(40, 96),
		"hand": Vector2i(16, 12), "moth": Vector2i(8, 7), "clock": Vector2i(24, 48)}
	for k: String in sizes:
		var img: Image = SpriteKit.horror_texture(k).get_image()
		assert_eq(img.get_size(), sizes[k], k)
		assert_true(_palette_ok(img), k)
		assert_true(_opaque_count(img) >= 12, k + " too empty")
		assert_true(img.get_pixel(0, 0).a < 0.01 or k == "portrait" or k == "clock" or k == "moth", k + " corner")
	# the wake silhouette is a dark figure on a dark red backdrop, not a bare rim
	var sil: Image = SpriteKit.horror_texture("silhouette").get_image()
	var reds: int = 0
	var blacks: int = 0
	for y: int in range(sil.get_height()):
		for x: int in range(sil.get_width()):
			var c: Color = sil.get_pixel(x, y)
			if c.a > 0.5 and c == RoomPalette.colors()[12]:
				reds += 1
			elif c.a > 0.5 and c == RoomPalette.colors()[0]:
				blacks += 1
	assert_true(reds > 600 and blacks > 600, "silhouette needs backdrop and figure: " + str(reds) + "/" + str(blacks))
	# the portrait leaves its eye sockets dark so the room can draw pupils there
	var pt: Image = SpriteKit.horror_texture("portrait").get_image()
	assert_true(pt.get_pixel(9, 13) == RoomPalette.colors()[0] and pt.get_pixel(14, 14) == RoomPalette.colors()[0])


func _mask_hash(img: Image) -> int:
	var bits: PackedByteArray = PackedByteArray()
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			bits.append(1 if img.get_pixel(x, y).a > 0.5 else 0)
	return hash(bits)


func _top_row(img: Image) -> int:
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				return y
	return img.get_height()


func test_customer_body_plans_give_distinct_silhouettes() -> void:
	var masks: Dictionary = {}
	var tops: Dictionary = {}
	for row: Dictionary in _rows(CUSTOMERS_PATH):
		var look: Dictionary = row.duplicate()
		look["height"] = 1.0
		var img: Image = SpriteKit.customer_texture(look).get_image()
		masks[_mask_hash(img)] = true
		tops[str(row["id"])] = _top_row(img)
	assert_eq(masks.size(), 12, "every customer type has its own silhouette")
	assert_true(int(tops["nervous_heir"]) > int(tops["medium"]) + 12, "the child figure stands much shorter")
	var plain: Image = SpriteKit.customer_texture({"id": "x", "cloak": "#4b2a78", "height": 1.0}).get_image()
	var broad: Image = SpriteKit.customer_texture({"id": "x", "cloak": "#4b2a78", "height": 1.0, "plan": "broad"}).get_image()
	var thin: Image = SpriteKit.customer_texture({"id": "x", "cloak": "#4b2a78", "height": 1.0, "plan": "tall"}).get_image()
	assert_true(_opaque_count(broad) > _opaque_count(plain) and _opaque_count(plain) > _opaque_count(thin), "broad > plain > thin")


func test_redrawn_toys_and_books_are_distinct_shapes() -> void:
	var masks: Dictionary = {}
	for id: String in ["porcelain_doll", "jack_in_box", "marionette", "toy_theatre", "diary", "hymnal", "almanac", "photo_album", "herbarium", "first_edition"]:
		var img: Image = SpriteKit.object_texture(id, "toy").get_image()
		assert_true(_opaque_count(img) > 220, id + " should be a substantial silhouette")
		masks[_mask_hash(img)] = true
	assert_eq(masks.size(), 10)


func test_croupier_has_four_distinct_palette_frames() -> void:
	var frames: Array[ImageTexture] = SpriteKit.croupier_frames()
	assert_eq(frames.size(), 4)
	var seen: Dictionary = {}
	for f: ImageTexture in frames:
		var img: Image = f.get_image()
		assert_eq(img.get_size(), Vector2i(64, 96))
		assert_true(_palette_ok(img))
		assert_true(_opaque_count(img) > 900)
		seen[hash(img.get_data())] = true
	assert_eq(seen.size(), 4)


func test_dice_and_card_faces_are_distinct_and_in_palette() -> void:
	var seen: Dictionary = {}
	for face: int in range(1, 7):
		var img: Image = SpriteKit.dice_texture(face).get_image()
		assert_eq(img.get_size(), Vector2i(12, 12))
		assert_true(_palette_ok(img), "dice %d" % face)
		seen[hash(img.get_data())] = true
	assert_eq(seen.size(), 6)
	assert_true(SpriteKit.dice_texture(7).get_image().get_data() == SpriteKit.dice_texture(1).get_image().get_data())
	seen.clear()
	for rank: int in range(1, 14):
		var img2: Image = SpriteKit.card_face_texture(rank).get_image()
		assert_eq(img2.get_size(), Vector2i(20, 30))
		assert_true(_palette_ok(img2), "card %d" % rank)
		seen[hash(img2.get_data())] = true
	assert_eq(seen.size(), 13)


func test_wheel_lot_and_page_sizes() -> void:
	var sizes: Dictionary = {"wheel": Vector2i(64, 64), "lot": Vector2i(32, 32), "page": Vector2i(24, 32)}
	var texes: Dictionary = {"wheel": SpriteKit.wheel_texture(), "lot": SpriteKit.lot_texture(), "page": SpriteKit.spell_page_texture()}
	for k: String in sizes:
		var img: Image = (texes[k] as ImageTexture).get_image()
		assert_eq(img.get_size(), sizes[k], k)
		assert_true(_palette_ok(img), k)
		assert_true(_opaque_count(img) > 300, k)


func test_spell_icons_are_distinct() -> void:
	var seen: Dictionary = {}
	for id: String in ["scry", "hex", "glamour", "banish", "summon", "seal"]:
		var img: Image = SpriteKit.spell_icon(id).get_image()
		assert_eq(img.get_size(), Vector2i(16, 16))
		assert_true(_palette_ok(img), id)
		assert_true(_opaque_count(img) > 50, id)
		seen[hash(img.get_data())] = true
	assert_eq(seen.size(), 6)


func test_every_curio_has_a_24px_icon_and_a_repeatable_one() -> void:
	var seen: Dictionary = {}
	var rows: Array = _rows("res://game/data/curios.json")
	for row: Dictionary in rows:
		var id: String = str(row["id"])
		var img: Image = SpriteKit.curio_icon(id).get_image()
		assert_eq(img.get_size(), Vector2i(24, 24), id)
		assert_true(_palette_ok(img), id)
		assert_true(_opaque_count(img) > 60, id)
		assert_true(img.get_data() == SpriteKit.curio_icon(id).get_image().get_data(), id + " repeat")
		seen[hash(img.get_data())] = true
	assert_eq(seen.size(), rows.size())
	assert_true(_opaque_count(SpriteKit.curio_icon("not_in_the_file").get_image()) > 60)
