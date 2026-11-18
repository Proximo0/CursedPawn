class_name TitleScreen
extends TsScreen
## The title screen at the room's 480x270 grid: CURSED PAWN in big pixel letters, the empty shop dim behind it,
## a hooded figure whose eyes blink, and the menu (Continue only with a saved run, New run, Settings, Quit not on
## the web). Up/Down/Enter or the mouse. It only emits; the host decides what a run start means:
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
const DIM_LEVEL: int = 5  # out of 16; higher hides the shop behind the title
const BTN_W: float = 128.0
const BTN_H: float = 17.0
const BTN_STEP: float = 21.0
const EYE_PERIOD: float = 3.4
const EYE_SHUT: float = 0.16
const HOOD_X: float = 440.0
const HOOD_BASE_Y: float = 170.0

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


# ---------------------------------------------------------------- drawing

func ts_draw_scene(c: TsCanvas) -> void:
	c.dim(Rect2(Vector2.ZERO, ShopGame.VIEW), DIM_LEVEL)
	_ts_draw_hood(c)
	if settings_open:
		c.dim(Rect2(Vector2.ZERO, ShopGame.VIEW), 4)  # the panel has the stage; the title steps back
		return
	c.dim(Rect2(0.0, 0.0, 480.0, 84.0), 5)  # a darker band behind the title
	var flick: bool = sin(c.t * 13.0) + sin(c.t * 5.3) > 1.75
	var col: int = 10 if flick else 11
	var tx: float = 240.0 - float(UiPixelFont.ui_width(TITLE, TITLE_SCALE)) * 0.5
	var ty: float = 18.0
	for off: Vector2 in [Vector2(4.0, 4.0), Vector2(3.0, 3.0), Vector2(2.0, 2.0)]:
		UiPixelFont.ui_draw(c, Vector2(tx, ty) + off, TITLE, c.c(0 if off.x > 3.0 else 12), TITLE_SCALE, false)
	UiPixelFont.ui_draw(c, Vector2(tx, ty), TITLE, c.c(col), TITLE_SCALE, false)
	c.text_c(240.0, 56.0, SUBTITLE, 14, 2)


func ts_draw_menu(c: TsCanvas) -> void:
	var entries: Array[Dictionary] = ts_entries(has_save, web)
	var y: float = 112.0
	if parcel:
		var pulse: bool = fmod(c.t, 1.6) < 0.9
		c.text_c(240.0, 94.0, PARCEL_LINE, 11 if pulse else 15, 1)
	else:
		y = 104.0
	for i: int in range(entries.size()):
		var e: Dictionary = entries[i]
		var rect := Rect2(240.0 - BTN_W * 0.5, y + BTN_STEP * float(i), BTN_W, BTN_H)
		c.button(str(e["id"]), rect, str(e["label"]), true, i == 0)
		if is_focused(str(e["id"])):
			c.text(Vector2(rect.position.x - 10.0, rect.position.y + 5.0), ">", 11)
	c.text_c(240.0, 258.0, "UP DOWN ENTER, OR CLICK", 4, 1)


## The hooded figure behind the counter; its eyes shut for a moment every EYE_PERIOD seconds.
func _ts_draw_hood(c: TsCanvas) -> void:
	var rows: int = 52
	for pass_i: int in range(2):
		for y: int in range(rows):
			var hw: float = _ts_hood_half_width(y)
			var grow: float = 1.0 if pass_i == 0 else 0.0
			var top: float = HOOD_BASE_Y - float(rows) + float(y)
			c.fill(Rect2(HOOD_X - hw - grow, top, 2.0 * hw + 2.0 * grow, 1.0), 0 if pass_i == 0 else 8)
			if pass_i == 1:
				c.fill(Rect2(HOOD_X - hw, top, 2.0, 1.0), 9)  # lit left edge
	c.fill(Rect2(HOOD_X - 1.0, HOOD_BASE_Y - 52.0, 2.0, 1.0), 0)
	var fy: float = HOOD_BASE_Y - 44.0  # the black face opening
	c.fill(Rect2(HOOD_X - 8.0, fy, 16.0, 20.0), 0)
	c.fill(Rect2(HOOD_X - 7.0, fy - 1.0, 14.0, 1.0), 0)
	if fmod(c.t, EYE_PERIOD) > EYE_SHUT:
		c.fill(Rect2(HOOD_X - 6.0, fy + 8.0, 4.0, 2.0), 10)
		c.fill(Rect2(HOOD_X + 2.0, fy + 8.0, 4.0, 2.0), 10)
		c.fill(Rect2(HOOD_X - 5.0, fy + 8.0, 2.0, 1.0), 11)
		c.fill(Rect2(HOOD_X + 3.0, fy + 8.0, 2.0, 1.0), 11)
	else:
		c.fill(Rect2(HOOD_X - 6.0, fy + 9.0, 4.0, 1.0), 9)
		c.fill(Rect2(HOOD_X + 2.0, fy + 9.0, 4.0, 1.0), 9)


func _ts_hood_half_width(y: int) -> float:
	if y < 4:
		return [5.0, 8.0, 10.0, 12.0][y]
	if y < 22:
		return 13.0
	return minf(13.0 + float(y - 21) * 0.9, 25.0)
