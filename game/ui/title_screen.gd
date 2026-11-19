class_name TitleScreen
extends TsScreen
## The title screen at the 640x360 grid. A near-black room with one candle; the title fades up out of the dark, the
## menu lights one entry at a time, and later a pair of eyes opens in the dark (a second, farther pair after that).
## The menu cursor is a flickering flame. Continue shows only with a saved run, Quit not on the web. Any key or click
## during the intro skips to the end of it. It only emits; the host decides what a run start means:
##   var title := TitleScreen.new(); title.has_save = ...; title.parcel = ...; add_child(title)
##   title.start_new.connect(...); title.continue_run.connect(...); title.quit.connect(get_tree().quit)
## Pass `room` (the host's ShopRoom2D) to reuse it; otherwise the title builds its own with an empty run.

signal start_new
signal continue_run
signal quit

const TITLE: String = "CURSED PAWN"
const SUBTITLE: String = "an occult pawnshop"
const PARCEL_LINE: String = "A parcel is waiting for you"
const TITLE_SCALE: int = 4
const BTN_W: float = 150.0
const BTN_H: float = 20.0
const BTN_STEP: float = 26.0
const MENU_X: float = 420.0
const CANDLE_POS := Vector2(150.0, 300.0)
const TITLE_AT: float = 0.9
const TITLE_FADE: float = 2.6
const SUB_AT: float = 3.2
const MENU_AT: float = 3.8
const MENU_STEP: float = 0.22
const EYES_AT: float = 5.6
const EYES2_AT: float = 9.5
const SKIP_TO: float = 5.0
## Title colours as the fade climbs: [main, highlight, lowlight, shadow] per step.
const FADE_STEPS: Array = [
	[8, 8, 1, 0], [9, 10, 8, 0], [10, 11, 9, 0], [11, 15, 10, 0], [11, 15, 9, 12],
]

var has_save: bool = false  ## show Continue
var parcel: bool = false  ## the page URL carried a gift: show the parcel line
var _own_room: bool = false


## The menu entries top to bottom: [{id, label}]. Continue needs a saved run; Quit is not offered on the web.
static func ts_entries(has_save_in: bool, web_in: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has_save_in:
		out.append({"id": "continue", "label": "CONTINUE"})
	out.append({"id": "new", "label": "NEW RUN"})
	out.append({"id": "settings", "label": "SETTINGS"})
	if not web_in:
		out.append({"id": "quit", "label": "QUIT"})
	return out


## True when the page URL carries a gift (`#gift=`). Always false off the web.
static func ts_parcel_in_page() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("window.location.hash", true)).begins_with(PassLink.FRAGMENT_KEY)


## True when a saved run is waiting (never in scripted runs).
static func ts_has_save() -> bool:
	return not Flags.is_scripted_run() and FileAccess.file_exists(PlayerProfile.RUN_PATH)


## Which fade step (0 = nothing yet .. FADE_STEPS.size() = full) the title is at after t seconds of the intro.
static func ts_fade_step(t: float) -> int:
	var p: float = UiMotion.ui_in_out((t - TITLE_AT) / TITLE_FADE)
	return clampi(int(p * float(FADE_STEPS.size() + 1)), 0, FADE_STEPS.size())


## How open a pair of eyes is (0 shut, 1 open) at intro time t: opens slowly from `start`, blinks now and then.
static func ts_eye_open(t: float, start: float) -> float:
	var o: float = UiMotion.ui_in_out((t - start) / 1.2)
	var ph: float = fmod(maxf(t - start, 0.0), 6.5)
	if o >= 1.0 and ph > 5.9 and ph < 6.1:
		return 0.0
	return o


func ts_ready() -> void:
	if room == null:
		room = ShopRoom2D.new()
		add_child(room)
		move_child(room, 0)
		room.setup(RunState.new())
		_own_room = true
	room.dither_enabled = settings.dither
	focus_id = ts_menu_ids()[0]


func ts_menu_ids() -> Array[String]:
	var ids: Array[String] = []
	for e: Dictionary in ts_entries(has_save, web):
		ids.append(str(e["id"]))
	return ids


func ts_activate_menu(id: String) -> void:
	match id:
		"continue":
			continue_run.emit()
		"new":
			start_new.emit()
		"settings":
			ts_open_settings()
		"quit":
			quit.emit()


func ts_escape_menu() -> void:
	pass


## A key press or click during the intro skips it instead of acting.
func ts_swallow(event: InputEvent) -> bool:
	if canvas == null or canvas.t >= SKIP_TO or settings_open:
		return false
	var key := event as InputEventKey
	var mb := event as InputEventMouseButton
	if (key != null and key.pressed and not key.echo) or (mb != null and mb.pressed):
		canvas.t = SKIP_TO
		return true
	return false


# ---------------------------------------------------------------- drawing

func ts_draw_scene(c: TsCanvas) -> void:
	var flick: bool = UiMotion.ui_hash(int(c.t * 9.0), 1) < 0.5
	c.light_pool(Vector2i(CANDLE_POS) - Vector2i(0, 36), 34.0, 196.0 if flick else 204.0, 15)
	UiFrames.ui_candle(c, CANDLE_POS.x, CANDLE_POS.y, 10, 40, c.t, 0, false, 3)
	_ts_draw_eyes(c, Vector2(522.0, 120.0), 11.0, ts_eye_open(c.t, EYES_AT), 13, 11)
	_ts_draw_eyes(c, Vector2(78.0, 104.0), 8.0, ts_eye_open(c.t, EYES2_AT) * 0.8, 12, 13)
	if settings_open:
		return
	var step: int = ts_fade_step(c.t)
	if step > 0:
		var cols := PackedInt32Array(FADE_STEPS[step - 1] as Array)
		if step == FADE_STEPS.size() and UiMotion.ui_hash(int(c.t * 13.0), 9) < 0.08:
			cols[0] = 10  # the title flickers like a failing flame
		var dw: int = UiPixelFont.ui_display_width(TITLE, TITLE_SCALE, true)
		UiPixelFont.ui_display_draw(c, Vector2(floorf(320.0 - float(dw) * 0.5), 74.0), TITLE, TITLE_SCALE, cols, c.t,
			0.0, 0.6 if step == FADE_STEPS.size() else 0.0, true)
	var sub_ramp: Array[int] = [1, 2, 3, 4, 14]
	var sp: float = clampf((c.t - SUB_AT) / 1.0, 0.0, 0.999)
	if c.t > SUB_AT:
		c.text_c(320.0, 144.0, SUBTITLE, sub_ramp[int(sp * 5.0)], 2, sp > 0.6)


## A pair of almond eyes: two eyes `gap` apart (centre of the pair at `at`); o is how open they are.
func _ts_draw_eyes(c: TsCanvas, at: Vector2, w: float, o: float, rim: int, core: int) -> void:
	var rows: int = int(round(o * 5.0))
	if rows <= 0:
		return
	var widths: Array[int] = [int(w) - 4, int(w), int(w), int(w) - 2, int(w) - 6]
	for side: int in range(2):
		var ex: float = at.x + (-1.0 if side == 0 else 1.0) * (w + 3.0)
		for i: int in range(rows):
			var ri: int = i + (5 - rows) / 2
			var ww: int = maxi(widths[ri], 1)
			var y: float = at.y + float(ri)
			c.fill(Rect2(ex - float(ww) * 0.5, y, float(ww), 1.0), rim)
			if ri >= 1 and ri <= 3 and ww > 3:
				c.fill(Rect2(ex - float(ww - 4) * 0.5, y, float(ww - 4), 1.0), core)
		if rows >= 3:
			c.fill(Rect2(ex, at.y + 1.0, 1.0, 3.0), 0)  # the slit pupil


func ts_draw_menu(c: TsCanvas) -> void:
	var entries: Array[Dictionary] = ts_entries(has_save, web)
	var y: float = 186.0
	if parcel and c.t > MENU_AT:
		var pulse: bool = fmod(c.t, 1.6) < 0.9
		c.text_c(MENU_X, 162.0, PARCEL_LINE, 11 if pulse else 15, 1)
	for i: int in range(entries.size()):
		var e: Dictionary = entries[i]
		var u: float = UiMotion.ui_out((c.t - MENU_AT - MENU_STEP * float(i)) / 0.35)
		var rect := Rect2(MENU_X - BTN_W * 0.5, y + BTN_STEP * float(i), BTN_W, BTN_H)
		if u <= 0.0:
			c.add(str(e["id"]), rect, false)
			continue
		var shown := Rect2(rect.position + Vector2(0.0, floorf((1.0 - u) * 10.0)), rect.size)
		c.button(str(e["id"]), shown, str(e["label"]), true, i == 0)
		if is_focused(str(e["id"])) and u >= 1.0:
			c.cursor_flame(Vector2(rect.position.x - 15.0, rect.position.y + 6.0))
	if c.t > MENU_AT + 0.8:
		c.text_c(MENU_X, 330.0, "UP DOWN ENTER, OR CLICK", 4, 1)
