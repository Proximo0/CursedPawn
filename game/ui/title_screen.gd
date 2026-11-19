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
signal start_daily
signal open_altar
signal skip_tutorial
signal open_test_menu
signal quit

const TITLE: String = "Cursed Pawn"  ## small caps after the capitals, so the letters read as deliberate
const SUBTITLE: String = "an occult pawnshop"
const PARCEL_LINE: String = "A parcel is waiting for you"
const TITLE_SCALE: int = 4
const BTN_W: float = 150.0
const BTN_H: float = 20.0
const BTN_STEP: float = 26.0
const BTN_STEP_TIGHT: float = 23.0
const MENU_X: float = 420.0
const CANDLE_POS := Vector2(150.0, 312.0)
const CANDLE_W: int = 16
const CANDLE_H: int = 54
const FLAME_PX: int = 3
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
var daily_on: bool = false  ## offer the Daily Seance (the logic for it exists)
var daily_number: int = 0  ## today's Seance number
var altar_on: bool = false  ## offer the Altar (the logic for upgrades exists)
var altar_ecto: int = 0  ## ectoplasm waiting to be spent: a green number beside the entry
var test_on: bool = false  ## debug and dev builds: offer the TEST MENU
var tutorial_on: bool = false  ## a first-time player: offer SKIP TUTORIAL
var notice: String = ""  ## a short line under the menu (a damaged save was reset)
var preview: Dictionary = {}  ## the saved run, for the Continue card: see ts_preview_of
var daily_line: String = ""  ## when today's was already played: its short result, shown under the menu
var _own_room: bool = false


## The menu entries top to bottom: [{id, label}]. Continue needs a saved run; Quit is not offered on the web.
static func ts_entries(has_save_in: bool, web_in: bool, daily_in: bool = false, daily_no: int = 0, altar_in: bool = false, ledger_in: bool = false, skip_in: bool = false, test_in: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has_save_in:
		out.append({"id": "continue", "label": "CONTINUE"})
	out.append({"id": "new", "label": "NEW RUN"})
	if skip_in:
		out.append({"id": "skip_tutorial", "label": "SKIP TUTORIAL"})
	if daily_in:
		out.append({"id": "daily", "label": "DAILY SEANCE #%d" % daily_no})
	if altar_in:
		out.append({"id": "altar", "label": "THE ALTAR"})
	if ledger_in:
		out.append({"id": "ledger", "label": "JOURNAL"})
	out.append({"id": "settings", "label": "SETTINGS"})
	if test_in:
		out.append({"id": "test", "label": "TEST MENU"})
	if not web_in:
		out.append({"id": "quit", "label": "QUIT"})
	return out


## The test menu shows in debug builds and with --dev, never in a release build otherwise.
static func ts_test_allowed() -> bool:
	return OS.is_debug_build() or Flags.dev_menu()


## What the Continue card shows for a saved run: {night, nights, cash, dread, items: [names], badge}.
static func ts_preview_of(r: RunState) -> Dictionary:
	if r == null:
		return {}
	var names: Array[String] = []
	for item: Dictionary in r.inventory:
		names.append(str(item.get("name", "?")))
	return {"night": r.night, "nights": int(r.tuning.nights), "cash": r.cash, "dread": clampf(r.dread / maxf(r.tuning.wake_threshold, 0.1), 0.0, 1.0),
		"items": names, "badge": str(UiEngage.badge_info(r).get("text", ""))}


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
	for e: Dictionary in ts_entries(has_save, web, daily_on, daily_number, altar_on, true, tutorial_on, test_on):
		ids.append(str(e["id"]))
	return ids


func ts_activate_menu(id: String) -> void:
	match id:
		"continue":
			continue_run.emit()
		"new":
			start_new.emit()
		"daily":
			start_daily.emit()
		"altar":
			open_altar.emit()
		"ledger":
			ts_open_ledger()
		"skip_tutorial":
			tutorial_on = false
			focus_id = "new"
			skip_tutorial.emit()
		"settings":
			ts_open_settings()
		"test":
			open_test_menu.emit()
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
	var flame_at: Vector2 = CANDLE_POS - Vector2(0.0, float(CANDLE_H) + float(FLAME_PX * 4))
	c.light_pool(Vector2i(flame_at), 46.0, 230.0 if flick else 240.0, 15)
	UiFrames.ui_glow(c, flame_at, 90 if flick else 96, 9, 10, 1.1)  # the warm pool the candle throws
	UiFrames.ui_glow(c, CANDLE_POS + Vector2(0.0, 4.0), 56, 8, 9, 0.7)  # and its light on the table
	UiFrames.ui_candle(c, CANDLE_POS.x, CANDLE_POS.y, CANDLE_W, CANDLE_H, c.t, 0, false, 3, FLAME_PX)
	_ts_draw_eyes(c, Vector2(556.0, 160.0), 24.0, ts_eye_open(c.t, EYES_AT), 13, 11)
	_ts_draw_eyes(c, Vector2(96.0, 96.0), 14.0, ts_eye_open(c.t, EYES2_AT) * 0.8, 12, 13)
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


## A pair of almond eyes, each row three pixels tall (about 15 px when open), `w` wide, a dither halo in the rim colour and
## a slit pupil; centre of the pair at `at`. o is how open they are (0..1). A flash of white as they first open.
func _ts_draw_eyes(c: TsCanvas, at: Vector2, w: float, o: float, rim: int, core: int) -> void:
	var rows: int = int(round(o * 5.0))
	if rows <= 0:
		return
	var widths: Array[int] = [int(w) - 6, int(w) - 1, int(w), int(w) - 2, int(w) - 8]
	var half: float = w * 0.5 + 6.0
	for side: int in range(2):
		var ex: float = at.x + (-1.0 if side == 0 else 1.0) * (w + 6.0)
		var ey: float = at.y + 7.0
		UiFrames.ui_glow(c, Vector2(ex, ey), int(half * 2.0), 1 if rim == 12 else 12, rim, 0.8 * o)
		for i: int in range(rows):
			var ri: int = i + (5 - rows) / 2
			var ww: int = maxi(widths[ri], 1)
			var y: float = at.y + float(ri * 3)
			c.fill(Rect2(ex - float(ww) * 0.5, y, float(ww), 3.0), rim)
			if ri >= 1 and ri <= 3 and ww > 4:
				c.fill(Rect2(ex - float(ww - 4) * 0.5, y, float(ww - 4), 3.0), core)
		if rows >= 3:
			c.fill(Rect2(ex - 1.0, at.y + 3.0, 3.0, 9.0), 0)  # the slit pupil
			c.fill(Rect2(ex - 5.0, at.y + 4.0, 2.0, 3.0), 15)  # a glint
		if o < 1.0 and rows >= 2:
			c.fill(Rect2(ex - 3.0, at.y + 6.0, 6.0, 3.0), 15)  # the white flash of waking


func ts_draw_menu(c: TsCanvas) -> void:
	var entries: Array[Dictionary] = ts_entries(has_save, web, daily_on, daily_number, altar_on, true, tutorial_on, test_on)
	var many: bool = entries.size() > 7
	var step: float = BTN_STEP if entries.size() <= 5 else (BTN_STEP_TIGHT if not many else 21.0)
	var y: float = 186.0 if entries.size() <= 5 else (176.0 if not many else 168.0)
	if parcel and c.t > MENU_AT:
		var pulse: bool = fmod(c.t, 1.6) < 0.9
		c.text_c(MENU_X, y - 24.0, PARCEL_LINE, 11 if pulse else 15, 1)
	for i: int in range(entries.size()):
		var e: Dictionary = entries[i]
		var u: float = UiMotion.ui_out((c.t - MENU_AT - MENU_STEP * float(i)) / 0.35)
		var bw: float = BTN_W + (46.0 if settings.text_scale == 2 else 0.0)
		var rect := Rect2(MENU_X - bw * 0.5, y + step * float(i), bw, BTN_H)
		if u <= 0.0:
			c.add(str(e["id"]), rect, false)
			continue
		var shown := Rect2(rect.position + Vector2(0.0, floorf((1.0 - u) * 10.0)), rect.size)
		c.button(str(e["id"]), shown, str(e["label"]), true, i == 0)
		if str(e["id"]) == "altar" and altar_ecto > 0 and u >= 1.0:
			var glow: int = 7 if fmod(c.t, 1.4) < 0.9 else 6
			c.text(Vector2(rect.end.x + 8.0, rect.position.y + 6.0), "%d" % altar_ecto, glow, 1)  # ectoplasm to spend
		if is_focused(str(e["id"])) and u >= 1.0:
			c.cursor_flame(Vector2(rect.position.x - 15.0, rect.position.y + 6.0))
	if not preview.is_empty() and focus_id == "continue" and c.t > MENU_AT + 0.4:
		_ts_draw_preview(c)
	if daily_line != "" and c.t > MENU_AT + 0.6:
		var dy: float = y + step * float(entries.size()) + 1.0
		c.text_c(MENU_X, dy, "PLAYED TODAY: " + daily_line, 14, 1)
	if notice != "" and c.t > MENU_AT + 0.3:
		c.text_c(MENU_X, 326.0, notice, 13, 1)
	if c.t > MENU_AT + 0.8 and not many:
		c.text_c(MENU_X, 340.0, "UP DOWN ENTER, OR CLICK", 4, 1)


## The Continue card: a note pinned over the dark with the saved run's night, cash, Dread candle and what is on the shelf.
func _ts_draw_preview(c: TsCanvas) -> void:
	var rc := Rect2(28.0, 168.0, 196.0, 96.0)
	c.frame(rc, "note")
	c.fill(Rect2(rc.position.x + 94.0, rc.position.y - 2.0, 3.0, 3.0), 13)  # the pin
	var x: float = rc.position.x + 10.0
	var y: float = rc.position.y + 9.0
	c.text(Vector2(x, y), "YOUR RUN, WAITING", 0, 1, false)
	c.text(Vector2(x, y + 12.0), "NIGHT %d OF %d" % [int(preview["night"]), int(preview["nights"])], 9, 1, false)
	c.text(Vector2(x + 100.0, y + 12.0), "%d COINS" % int(preview["cash"]), 8, 1, false)
	var dread: float = float(preview["dread"])
	c.text(Vector2(x, y + 26.0), "DREAD", 9, 1, false)
	c.fill(Rect2(x + 36.0, y + 27.0, 100.0, 6.0), 1)
	c.fill(Rect2(x + 36.0, y + 27.0, 100.0 * dread, 6.0), 13 if dread > 0.7 else 10)
	var items: Array = preview["items"] as Array
	var line: String = ", ".join(PackedStringArray(items.slice(0, 3))).to_upper() if not items.is_empty() else "THE SHELF IS BARE"
	var wrapped: PackedStringArray = UiPixelFont.ui_wrap(line, 176)
	for i: int in range(mini(wrapped.size(), 2)):
		c.text(Vector2(x, y + 40.0 + float(i * UiPixelFont.LINE_H)), wrapped[i], 0, 1, false)
	if str(preview["badge"]) != "":
		c.text(Vector2(x, y + 66.0), str(preview["badge"]), 9, 1, false)
