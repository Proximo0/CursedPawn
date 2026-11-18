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


func test_glyph_rows_fit_five_bits() -> void:
	for code: int in range(32, 127):
		var rows: PackedInt32Array = UiPixelFont.ui_glyph_rows(char(code))
		assert_eq(rows.size(), 7)
		for row: int in rows:
			assert_true(row >= 0 and row < 32, "glyph %d row %d" % [code, row])


func test_unknown_character_falls_back_to_question_mark() -> void:
	assert_eq(UiPixelFont.ui_glyph_rows("é"), UiPixelFont.ui_glyph_rows("?"))


func test_width_and_wrap() -> void:
	assert_eq(UiPixelFont.ui_width("ABC"), 17)
	assert_eq(UiPixelFont.ui_width("ABC", 2), 34)
	var lines: PackedStringArray = UiPixelFont.ui_wrap("the quick brown fox jumps over", 60)
	assert_true(lines.size() >= 3)
	for l: String in lines:
		assert_true(UiPixelFont.ui_width(l) <= 60, l)
	assert_eq(UiPixelFont.ui_wrap("abcdefghijklmnopqrstuvwxyz", 30)[0].length(), 5)


func test_frames_use_only_palette_colours() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	for kind: String in UiFrames.KINDS:
		var img: Image = UiFrames.ui_texture(kind).get_image()
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.0:
					assert_true(pal.has(c), "%s pixel %d,%d" % [kind, x, y])
