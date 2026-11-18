extends TestCase


func test_palette_has_16_distinct_colours() -> void:
	var cols: PackedColorArray = RoomPalette.colors()
	assert_eq(cols.size(), 16)
	for i: int in range(cols.size()):
		for j: int in range(i + 1, cols.size()):
			assert_false(cols[i].is_equal_approx(cols[j]), "colours %d and %d equal" % [i, j])


func test_palette_spans_dark_to_light() -> void:
	var lo: float = 1.0
	var hi: float = 0.0
	for c: Color in RoomPalette.colors():
		lo = minf(lo, RoomPalette.luminance(c))
		hi = maxf(hi, RoomPalette.luminance(c))
	assert_true(lo < 0.05 and hi > 0.85, "lo %f hi %f" % [lo, hi])


func test_shader_has_all_colours_and_dither() -> void:
	var code: String = RoomPalette.shader_code()
	assert_true(code.contains("BAYER") and code.contains("PAL[16]"))
	assert_eq(code.count("vec3(0."), 16 + code.count("vec3(0.30"), "palette literals")
