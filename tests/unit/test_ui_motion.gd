extends TestCase


func test_easing_endpoints_and_monotonic() -> void:
	for f: Callable in [UiMotion.ui_out, UiMotion.ui_in, UiMotion.ui_in_out]:
		assert_eq(f.call(0.0), 0.0)
		assert_eq(f.call(1.0), 1.0)
		assert_eq(f.call(-3.0), 0.0)
		assert_eq(f.call(9.0), 1.0)
		var last: float = -1.0
		for i: int in range(11):
			var v: float = f.call(float(i) / 10.0)
			assert_true(v >= last)
			last = v
	assert_true(UiMotion.ui_out(0.5) > 0.5, "ease out leads")
	assert_true(UiMotion.ui_in(0.5) < 0.5, "ease in lags")
	assert_true(UiMotion.ui_back(0.7) > 1.0, "back overshoots")
	assert_eq(UiMotion.ui_back(1.0), 1.0)


func test_approach_and_hash() -> void:
	assert_true(UiMotion.ui_approach(0.0, 1.0, 0.1, 10.0) > 0.5)
	assert_eq(UiMotion.ui_approach(0.5, 0.5, 0.1, 10.0), 0.5)
	assert_eq(UiMotion.ui_hash(3, 4, 5), UiMotion.ui_hash(3, 4, 5))
	var distinct: Dictionary = {}
	for i: int in range(50):
		var h: float = UiMotion.ui_hash(i, 7)
		assert_true(h >= 0.0 and h <= 1.0)
		distinct[h] = true
	assert_true(distinct.size() > 40)


func test_hint_flutter_settles() -> void:
	assert_eq(TsHintFrame.ts_offset(TsHintFrame.FLUTTER_SECS + 0.1), Vector2.ZERO)
	assert_true(TsHintFrame.ts_offset(0.0).y < -10.0, "starts above its place")
	var moved: bool = false
	for i: int in range(12):
		moved = moved or TsHintFrame.ts_offset(0.05 * float(i)).x != 0.0
	assert_true(moved, "sways while falling")
	assert_true(TsHintFrame.ts_size("Inspect with 1-4 before you buy.").x < TsHintFrame.MAX_W)


func test_candle_burns_down_and_flame_stages() -> void:
	assert_eq(UiHud.ui_candle_height(0.0), UiHud.CANDLE_MAX_H)
	assert_eq(UiHud.ui_candle_height(1.0), UiHud.CANDLE_MIN_H)
	assert_true(UiHud.ui_candle_height(0.3) > UiHud.ui_candle_height(0.6))
	assert_eq(UiHud.ui_flame_size(0.1), 0)
	assert_eq(UiHud.ui_flame_size(0.6), 1)
	assert_eq(UiHud.ui_flame_size(0.9), 2)
	assert_eq(UiHud.ui_flame_size(1.0), -1)


func test_title_intro_sequence() -> void:
	assert_eq(TitleScreen.ts_fade_step(0.0), 0, "near black at first")
	assert_true(TitleScreen.ts_fade_step(TitleScreen.TITLE_AT + TitleScreen.TITLE_FADE + 1.0) == TitleScreen.FADE_STEPS.size())
	var last: int = 0
	for i: int in range(40):
		var s: int = TitleScreen.ts_fade_step(float(i) * 0.15)
		assert_true(s >= last)
		last = s
	assert_eq(TitleScreen.ts_eye_open(TitleScreen.EYES_AT - 1.0, TitleScreen.EYES_AT), 0.0)
	assert_eq(TitleScreen.ts_eye_open(TitleScreen.EYES_AT + 3.0, TitleScreen.EYES_AT), 1.0)
	assert_eq(TitleScreen.ts_eye_open(TitleScreen.EYES_AT + 6.0, TitleScreen.EYES_AT), 0.0, "blinks")
	assert_true(TitleScreen.SKIP_TO > TitleScreen.MENU_AT + 3.0 * TitleScreen.MENU_STEP + 0.4, "skipping shows the whole menu")
	assert_true(TitleScreen.SKIP_TO < TitleScreen.EYES_AT, "the eyes still open after a skip")
