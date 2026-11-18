extends TestCase

const SD_EVENTS: Array = [
	{"e": "night_start", "night": 2, "rent": 60},
	{"e": "customer", "kind": "seller", "name": "Mug", "ask": 40},
	{"e": "customer", "kind": "buyer", "category": "toy"},
	{"e": "inspected", "tool": "uv", "tell": "glows", "estimate": {"mid": 50, "spread": 0.3}},
	{"e": "counter", "offer": 10, "ask": 30, "patience": 2},
	{"e": "left", "offer": 5},
	{"e": "bought", "uid": 1, "name": "Mug", "price": 20},
	{"e": "sold", "uid": 1, "name": "Mug", "price": 50, "imposter": false},
	{"e": "passed", "kind": "seller"},
	{"e": "wake", "night": 3, "dread": 4.5, "broke": "Mug", "closed": true},
	{"e": "night_end", "night": 1, "rent": 40, "cash": 90},
	{"e": "run_lost", "night": 2, "cash": 5, "rent": 60},
	{"e": "run_won", "cash": 300},
	{"e": "invalid", "why": "tool uv"},
]


func test_every_event_has_text() -> void:
	for e: Dictionary in SD_EVENTS:
		var s: String = ShopDebug.sd_event_text(e)
		assert_true(s != "" and not s.begins_with("Unknown"), str(e["e"]))


func test_event_details() -> void:
	assert_true(ShopDebug.sd_event_text(SD_EVENTS[3]).contains("50 +- 30%"))
	assert_true(ShopDebug.sd_event_text(SD_EVENTS[9]).contains("Mug"))
	assert_true(ShopDebug.sd_event_text({"e": "zzz"}).begins_with("Unknown"))


func test_estimate_text() -> void:
	assert_eq(ShopDebug.sd_estimate_text({}), "?")


func test_overlay_format() -> void:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	var s: String = DebugOverlay.ov_format(run.debug_frame())
	assert_true(s.contains("night 1") and s.contains("night_start"))
