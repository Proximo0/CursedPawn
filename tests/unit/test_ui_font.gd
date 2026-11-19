extends TestCase


func test_font_covers_printable_ascii() -> void:
	for code: int in range(32, 127):
		var px: int = UiPixelFont.ui_glyph_pixels(char(code))
		if code == 32:
			assert_eq(px, 0, "space is blank")
		else:
			assert_true(px > 0, "glyph %d (%s) is empty" % [code, char(code)])


func test_glyphs_are_distinct() -> void:
	var seen: Dictionary = {}
	for code: int in range(33, 127):
		var key: String = str(UiPixelFont.ui_glyph_rows(char(code)))
		assert_false(seen.has(key), "glyph %s duplicates %s" % [char(code), str(seen.get(key, ""))])
		seen[key] = char(code)


func test_glyph_rows_fit_five_bits_and_descenders_drop_two_rows() -> void:
	for code: int in range(32, 127):
		var rows: PackedInt32Array = UiPixelFont.ui_glyph_rows(char(code))
		assert_eq(rows.size(), UiPixelFont.ROWS)
		for row: int in rows:
			assert_true(row >= 0 and row < 32, "glyph %d row %d" % [code, row])
	for ch: String in ["g", "j", "p", "q", "y"]:
		var rows: PackedInt32Array = UiPixelFont.ui_glyph_rows(ch)
		assert_true(rows[7] != 0 and rows[8] != 0, "%s descends below the baseline" % ch)
	for ch: String in ["a", "e", "T", "0"]:
		var rows: PackedInt32Array = UiPixelFont.ui_glyph_rows(ch)
		assert_true(rows[7] == 0 and rows[8] == 0, "%s sits on the baseline" % ch)


func test_unknown_character_falls_back_to_question_mark() -> void:
	assert_eq(UiPixelFont.ui_glyph_rows("é"), UiPixelFont.ui_glyph_rows("?"))


func test_width_kerning_and_wrap() -> void:
	assert_eq(UiPixelFont.ui_width("ABC"), 17)
	assert_eq(UiPixelFont.ui_width("ABC", 2), 34)
	assert_true(UiPixelFont.ui_width("ill") < UiPixelFont.ui_width("ABC"), "narrow letters tuck in")
	var lines: PackedStringArray = UiPixelFont.ui_wrap("the quick brown fox jumps over", 60)
	assert_true(lines.size() >= 3)
	for l: String in lines:
		assert_true(UiPixelFont.ui_width(l) <= 60, l)
	assert_eq(UiPixelFont.ui_wrap("abcdefghijklmnopqrstuvwxyz", 30)[0].length(), 5)


func test_head_font_has_every_heading_character() -> void:
	for i: int in range(UiPixelFont.HEAD_ORDER.length()):
		var ch: String = UiPixelFont.HEAD_ORDER[i]
		var rows: PackedInt32Array = UiPixelFont.ui_head_rows(ch)
		assert_eq(rows.size(), UiPixelFont.HEAD_ROWS)
		var lit: int = 0
		for row: int in rows:
			assert_true(row >= 0 and row < (1 << UiPixelFont.HEAD_BITS_W), ch)
			lit += 1 if row != 0 else 0
		assert_true(lit > 0, "head glyph %s is empty" % ch)
	for text: String in ["NIGHT 1/5", "SOMETHING WOKE", "YOU SURVIVED", "THE SHOP IS LOST", "CURSED PAWN", "SETTINGS", "PAUSED"]:
		for ch: String in text:
			assert_true(ch == " " or UiPixelFont.ui_head_supports(ch), "%s in %s" % [ch, text])
	assert_true(UiPixelFont.ui_head_rows("a") != UiPixelFont.ui_head_rows("A"), "lowercase is its own small-cap set")
	var small_top: int = 11
	for ch: String in "abcdefghijklmnopqrstuvwxyz":
		var rows: PackedInt32Array = UiPixelFont.ui_head_rows(ch)
		for y: int in range(UiPixelFont.HEAD_ROWS):
			if rows[y] != 0:
				small_top = mini(small_top, y)
		assert_true(rows[9] != 0, "%s sits on the capital baseline" % ch)
	assert_true(small_top >= 3, "small caps are shorter than capitals")


func test_head_glyphs_are_distinct() -> void:
	var seen: Dictionary = {}
	for i: int in range(UiPixelFont.HEAD_ORDER.length()):
		var ch: String = UiPixelFont.HEAD_ORDER[i]
		var key: String = str(UiPixelFont.ui_head_rows(ch))
		assert_false(seen.has(key), "%s duplicates %s" % [ch, str(seen.get(key, ""))])
		seen[key] = ch
	assert_true(UiPixelFont.ui_head_width("CURSED", 2) > UiPixelFont.ui_head_width("CURSED", 1))


func test_display_glyphs_are_palette_only_and_bevelled() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var cols: PackedInt32Array = PackedInt32Array([11, 15, 9, 0])
	var img: Image = UiPixelFont.ui_display_tex("C".unicode_at(0), 3, cols).get_image()
	var seen: Dictionary = {}
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.0:
				assert_true(pal.has(c), "pixel %d,%d" % [x, y])
				seen[c] = true
	assert_true(seen.has(pal[11]) and seen.has(pal[15]) and seen.has(pal[9]) and seen.has(pal[0]), "main, light, dark, shadow all show")


func test_frames_use_only_palette_colours() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	for kind: String in UiFrames.KINDS:
		var img: Image = UiFrames.ui_image(kind, 60, 30)
		var opaque: int = 0
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.0:
					opaque += 1
					assert_true(pal.has(c), "%s pixel %d,%d" % [kind, x, y])
		assert_true(opaque > 60 * 30 * 8 / 10, kind + " mostly filled")
		assert_eq(img.get_pixel(0, 0).a, 0.0, kind + " corner is cut")


func test_frames_are_deterministic_and_cached() -> void:
	assert_eq(UiFrames.ui_image("note", 40, 20).get_data(), UiFrames.ui_image("note", 40, 20).get_data())
	assert_true(UiFrames.ui_image("note", 40, 20).get_data() != UiFrames.ui_image("note", 41, 20).get_data())
	assert_true(UiFrames.ui_texture("panel", Vector2i(30, 20)) == UiFrames.ui_texture("panel", Vector2i(30, 20)))


func test_button_state_kinds_and_hover_flicker() -> void:
	assert_eq(UiFrames.ui_button_kind(false, false, true, true, 1.0), "btn_off")
	assert_eq(UiFrames.ui_button_kind(true, true, true, true, 1.0), "gold_down")
	assert_eq(UiFrames.ui_button_kind(false, true, true, false, 5.0), "btn_hover")
	assert_eq(UiFrames.ui_button_kind(false, true, false, false, 0.0), "btn")
	var kinds: Dictionary = {}
	for i: int in range(8):
		kinds[UiFrames.ui_button_kind(false, true, true, false, float(i) * 0.025)] = true
	assert_true(kinds.has("btn") and kinds.has("btn_hover"), "hover flickers on arrival")
