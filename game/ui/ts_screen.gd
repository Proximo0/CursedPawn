class_name TsScreen
extends Control
## Base of the title screen and the pause menu: a 640x360 canvas in a SubViewport scaled like the room (letterboxed),
## keyboard focus (Up/Down/Enter/Esc) and mouse mapped back to the grid, and the settings panel both share.
## While visible the screen eats all input (it is a modal). Subclasses fill the ts_* hooks and never override _ready.

const SETTINGS_RECT := Rect2(120.0, 14.0, 400.0, 332.0)
const FOCUS_VOLUME: String = "volume"
const TABS: Array[String] = ["audio", "display", "game", "keys"]
const TAB_LABELS: Dictionary = {"audio": "AUDIO", "display": "DISPLAY", "game": "GAME", "keys": "KEYS"}
const SLIDERS: Array[String] = ["volume", "sfx", "music", "shake"]

var settings: TsSettings = TsSettings.shared()
var sfx: SfxPlayer  ## optional: click and hover sounds, and where volume/mute are applied
var room: ShopRoom2D  ## optional: where the dither setting is applied
var web: bool = OS.has_feature("web")  ## injectable for tests; web hides Quit and Fullscreen
var desktop: bool = TsSettings.ts_is_desktop()
var settings_open: bool = false
var settings_tab: String = "audio"
var rebinding: String = ""  ## the action waiting for its new key
var focus_id: String = ""
var down_id: String = ""
var reset_msg: String = ""
var canvas: TsCanvas
var profile: Object  ## optional: the player profile (RelicStore); the Ledger reads deeds and regulars from it
signal replay_seed(entry: Dictionary)

var ledger := UiLedger.new()
var ledger_open: bool = false

var _view: TextureRect
var _vp: SubViewport


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = Vector2i(ShopGame.VIEW)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_disable_input = true
	add_child(_vp)
	canvas = TsCanvas.new()
	canvas.screen = self
	_vp.add_child(canvas)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ShopGame.ui_place(_view, get_viewport().get_visible_rect().size)
	_view.z_index = 100
	_view.z_as_relative = false
	add_child(_view)
	visibility_changed.connect(_ts_on_visibility)
	settings.apply(sfx, room)
	ts_ready()
	_ts_on_visibility()


func _process(delta: float) -> void:
	ledger.age += delta
	if _view != null:
		ShopGame.ui_place(_view, get_viewport().get_visible_rect().size)


## A hidden screen stops rendering (its SubViewport would otherwise redraw 60 times a second for nothing).
func _ts_on_visibility() -> void:
	var on: bool = is_visible_in_tree()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	canvas.set_process(on)


# ---------------------------------------------------------------- hooks for subclasses

func ts_ready() -> void:
	pass


## Draws the scene behind the menu (backdrop, title, dim).
func ts_draw_scene(_c: TsCanvas) -> void:
	pass


## Draws the main menu (not the settings panel) and adds its buttons with c.button.
func ts_draw_menu(_c: TsCanvas) -> void:
	pass


## The focusable ids of the main menu, top to bottom.
func ts_menu_ids() -> Array[String]:
	return []


func ts_activate_menu(_id: String) -> void:
	pass


## True when the screen swallows this input event itself (the title's intro skip). Default: never.
func ts_swallow(_event: InputEvent) -> bool:
	return false


## Esc on the main menu.
func ts_escape_menu() -> void:
	pass


# ---------------------------------------------------------------- focus and settings

func ts_draw(c: TsCanvas) -> void:
	ts_draw_scene(c)
	if ledger_open:
		ledger.draw(c, self)
	elif settings_open:
		_ts_draw_settings(c)
	else:
		ts_draw_menu(c)


func is_focused(id: String) -> bool:
	return focus_id == _ts_focus_of(id)


## The focusable ids on screen now (the settings panel's while it is open).
func ts_focus_ids() -> Array[String]:
	if ledger_open:
		return ledger.focus_ids()
	return ts_settings_ids(desktop, settings_tab) if settings_open else ts_menu_ids()


## The setting rows of one tab, top to bottom.
static func ts_tab_rows(tab: String, has_fullscreen: bool) -> Array[String]:
	var out: Array[String] = []
	match tab:
		"audio":
			out.append_array(["volume", "sfx", "music", "mute"] as Array[String])
		"display":
			out.append_array(["shake", "flash", "dither"] as Array[String])
			if has_fullscreen:
				out.append_array(["fullscreen", "window"] as Array[String])
		"game":
			out.append_array(["scares", "text_speed", "text_size", "colorblind", "reset_hints", "diag"] as Array[String])
		"keys":
			for a: Dictionary in TsKeys.ACTIONS:
				out.append("key:" + str(a["id"]))
	return out


## Every focusable id while the settings panel shows `tab`: the rows, then the reset button, the tabs and Back.
static func ts_settings_ids(has_fullscreen: bool, tab: String = "audio") -> Array[String]:
	var out: Array[String] = ts_tab_rows(tab, has_fullscreen)
	out.append("reset_all")
	for t: String in TABS:
		out.append("tab:" + t)
	out.append("settings_back")
	return out


func _ts_focus_of(id: String) -> String:
	if id.ends_with("_dec") or id.ends_with("_inc"):
		var row: String = id.left(id.length() - 4)
		return FOCUS_VOLUME if row == "vol" else row
	return id


func ts_set_focus(id: String) -> void:
	var f: String = _ts_focus_of(id)
	if f != focus_id and ts_focus_ids().has(f):
		focus_id = f


func ts_move_focus(dir: int) -> void:
	var ids: Array[String] = ts_focus_ids()
	if ids.is_empty():
		return
	var at: int = ids.find(focus_id)
	focus_id = ids[posmod(at + dir, ids.size())]
	if sfx != null:
		sfx.ui("hover")


func ts_open_ledger() -> void:
	ledger.open_from(profile)
	ledger_open = true
	focus_id = "ledger_tab_deeds"


func ts_close_ledger() -> void:
	ledger_open = false
	var ids: Array[String] = ts_menu_ids()
	focus_id = "ledger" if ids.has("ledger") else (ids[0] if not ids.is_empty() else "")


func ts_open_settings() -> void:
	settings_open = true
	settings_tab = "audio"
	rebinding = ""
	reset_msg = ""
	focus_id = FOCUS_VOLUME


func ts_close_settings(back_to: String) -> void:
	settings_open = false
	var ids: Array[String] = ts_menu_ids()
	focus_id = back_to if ids.has(back_to) else (ids[0] if not ids.is_empty() else "")


## One widget was activated (click or Enter). Settings ids are handled here, the rest by the subclass.
func ts_activate(id: String) -> void:
	if sfx != null:
		sfx.ui("click")
	if ledger_open:
		if id == "ledger_back":
			ts_close_ledger()
		else:
			ledger.activate(id)
			if not ledger.replay_entry.is_empty():
				var entry: Dictionary = ledger.replay_entry
				ledger.replay_entry = {}
				ts_close_ledger()
				replay_seed.emit(entry)
				return
			if not ts_focus_ids().has(focus_id):
				focus_id = "ledger_tab_deeds"
		return
	if not settings_open:
		ts_activate_menu(id)
		return
	var row: String = _ts_focus_of(id)
	if id.begins_with("tab:"):
		_ts_set_tab(id.trim_prefix("tab:"))
		return
	if id.begins_with("key:"):
		rebinding = "" if rebinding == id.trim_prefix("key:") else id.trim_prefix("key:")
		return
	match id:
		"diag":
			var report: String = DiagLog.copy_report()
			reset_msg = "COPIED %d LINES FOR A BUG REPORT." % report.count("\n") if report != "" else "NOTHING TO COPY."
			return
		"reset_hints":
			settings.reset_hints()
			reset_msg = "HINTS WILL SHOW AGAIN."
		"reset_all":
			if settings_tab == "keys":
				settings.keys = {}
				reset_msg = "KEYS BACK TO THEIR DEFAULTS."
			else:
				settings.reset_defaults()
				reset_msg = "EVERYTHING BACK TO ITS DEFAULT."
		"settings_back":
			ts_close_settings("settings")
			return
		_:
			var dir: int = -1 if id.ends_with("_dec") else 1
			if not settings.adjust(row, dir):
				return
	settings.apply(sfx, room)
	settings.save_player()


func _ts_set_tab(tab: String) -> void:
	if TABS.has(tab):
		settings_tab = tab
		rebinding = ""
		reset_msg = ""


func ts_escape() -> void:
	if ledger_open:
		ts_close_ledger()
	elif settings_open:
		ts_close_settings("settings")
	else:
		ts_escape_menu()


func ts_key(k: int) -> bool:
	if settings_open and rebinding != "":
		if k != KEY_ESCAPE:
			settings.keys = TsKeys.rebind(settings.keys, rebinding, k)
			settings.apply(sfx, room)
			settings.save_player()
			reset_msg = "%s IS NOW %s." % [rebinding.replace("_", " ").to_upper(), TsKeys.name_of(k)]
		rebinding = ""
		return true
	match k:
		KEY_UP:
			ts_move_focus(-1)
		KEY_DOWN:
			ts_move_focus(1)
		KEY_LEFT, KEY_RIGHT:
			var dir: int = -1 if k == KEY_LEFT else 1
			if ledger_open:
				ledger.turn(dir)
			elif settings_open and focus_id.begins_with("tab:"):
				_ts_set_tab(TABS[posmod(TABS.find(focus_id.trim_prefix("tab:")) + dir, TABS.size())])
				focus_id = "tab:" + settings_tab
			elif settings_open and ts_tab_rows(settings_tab, desktop).has(focus_id) and not focus_id.begins_with("key:") and focus_id != "reset_hints":
				ts_activate(focus_id + ("_inc" if dir > 0 else "_dec"))
		KEY_PAGEUP, KEY_PAGEDOWN:
			if settings_open:
				_ts_set_tab(TABS[posmod(TABS.find(settings_tab) + (1 if k == KEY_PAGEDOWN else -1), TABS.size())])
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if focus_id != "" and not (settings_open and SLIDERS.has(focus_id)):
				ts_activate(focus_id)
		KEY_ESCAPE:
			ts_escape()
		_:
			return false
	return true


# ---------------------------------------------------------------- settings panel

func _ts_draw_settings(c: TsCanvas) -> void:
	var r: Rect2 = SETTINGS_RECT
	c.frame(r, "panel")
	var cx: float = r.position.x + r.size.x * 0.5
	c.head_c(cx, r.position.y + 10.0, "SETTINGS", 11, 2)
	var tw: float = 84.0
	var tx: float = cx - tw * 2.0 - 6.0
	for t: String in TABS:
		c.button("tab:" + t, Rect2(tx, r.position.y + 32.0, tw, 17.0), str(TAB_LABELS[t]), true, t == settings_tab)
		_ts_focus_mark(c, "tab:" + t, Vector2(tx - 7.0, r.position.y + 36.0))
		tx += tw + 4.0
	c.fill(Rect2(r.position.x + 14.0, r.position.y + 54.0, r.size.x - 28.0, 1.0), 9)
	c.fill(Rect2(r.position.x + 14.0, r.position.y + 55.0, r.size.x - 28.0, 1.0), 8)
	var lx: float = r.position.x + 22.0
	var rx: float = r.end.x - 18.0
	var y: float = r.position.y + 64.0
	if settings_tab == "keys":
		_ts_draw_keys(c, r, y)
		y += 9.0 * 20.0 + 4.0
	else:
		for id: String in ts_tab_rows(settings_tab, desktop):
			_ts_draw_row(c, id, lx, rx, y)
			y += 25.0
	var note: String = reset_msg
	if rebinding != "":
		note = "PRESS THE NEW KEY FOR " + rebinding.replace("_", " ").to_upper() + ". ESC CANCELS."
	elif focus_id == "scares":
		note = "GENTLE: NO FLASHES, NO LOUD STINGERS."
	elif focus_id == "colorblind":
		note = "ADDS SHAPES AND WORDS BESIDE COLOUR-ONLY SIGNALS."
	elif focus_id == "text_size":
		note = "2X MAKES MENU AND LOG TEXT LARGER."
	if note != "":
		c.text_c(cx, r.end.y - 62.0, note, 14, 1)
	c.button("reset_all", Rect2(cx - 80.0, r.end.y - 48.0, 160.0, 17.0), "RESET KEYS" if settings_tab == "keys" else "RESET TO DEFAULT", true)
	_ts_focus_mark(c, "reset_all", Vector2(cx - 92.0, r.end.y - 43.0))
	c.button("settings_back", Rect2(cx - 44.0, r.end.y - 27.0, 88.0, 19.0), "BACK [ESC]", true, true)
	_ts_focus_mark(c, "settings_back", Vector2(cx - 56.0, r.end.y - 22.0))


const ROW_LABELS: Dictionary = {"volume": "MASTER", "sfx": "EFFECTS", "music": "MUSIC", "mute": "SOUND", "shake": "SCREEN SHAKE",
	"flash": "FLASHES", "dither": "DITHER", "fullscreen": "FULLSCREEN", "window": "WINDOW SIZE", "scares": "SCARES",
	"text_speed": "TEXT SPEED", "text_size": "TEXT SIZE", "colorblind": "COLOUR-BLIND TELLS"}


func _ts_draw_row(c: TsCanvas, id: String, lx: float, rx: float, y: float) -> void:
	if id == "diag":
		c.button("diag", Rect2(lx, y, rx - lx, 19.0), "COPY DIAGNOSTICS", true)
		_ts_focus_mark(c, id, Vector2(lx - 11.0, y + 6.0))
		return
	if id == "reset_hints":
		c.button("reset_hints", Rect2(lx, y, rx - lx, 19.0), "RESET TUTORIAL HINTS", true)
		_ts_focus_mark(c, id, Vector2(lx - 11.0, y + 6.0))
		return
	c.text(Vector2(lx, y + 6.0), str(ROW_LABELS.get(id, id)), 15)
	if SLIDERS.has(id):
		var key: String = "vol" if id == "volume" else id
		c.button(key + "_dec", Rect2(rx - 90.0, y, 16.0, 19.0), "-", true)
		c.frame(Rect2(rx - 72.0, y, 44.0, 19.0), "btn_off")
		c.text_c(rx - 50.0, y + 6.0, settings.value_text(id), 11, 1)
		c.button(key + "_inc", Rect2(rx - 26.0, y, 16.0, 19.0), "+", true)
	else:
		c.button(id, Rect2(rx - 90.0, y, 90.0, 19.0), settings.value_text(id), true)
	_ts_focus_mark(c, id, Vector2(lx - 11.0, y + 6.0))


func _ts_draw_keys(c: TsCanvas, r: Rect2, y0: float) -> void:
	var half: int = 10
	for i: int in range(TsKeys.ACTIONS.size()):
		var a: Dictionary = TsKeys.ACTIONS[i]
		var col: int = i / half
		var row: int = i % half
		var x: float = r.position.x + 22.0 + float(col) * 188.0
		var y: float = y0 + float(row) * 20.0
		var id: String = "key:" + str(a["id"])
		c.text(Vector2(x, y + 5.0), str(a["label"]), 15)
		var waiting: bool = rebinding == str(a["id"])
		c.button(id, Rect2(x + 100.0, y, 62.0, 16.0), "PRESS..." if waiting else TsKeys.label_of(str(a["id"])), true, waiting)
		_ts_focus_mark(c, id, Vector2(x - 9.0, y + 4.0))


## A small flickering flame beside the focused row, so keyboard focus reads at a glance.
func _ts_focus_mark(c: TsCanvas, id: String, at: Vector2) -> void:
	if focus_id == id:
		c.cursor_flame(at - Vector2(0.0, 1.0))


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or canvas == null:
		return
	if ts_swallow(event):
		get_viewport().set_input_as_handled()
		return
	TsPad.note(event)
	var pk: int = TsPad.key_for(event)
	if pk != 0:
		ts_key(pk)
		get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		var id: String = canvas.widget_at(_ts_view_pos(mm.position))
		if id != "" and _ts_focus_of(id) != focus_id:
			ts_set_focus(id)
			if sfx != null:
				sfx.ui("hover")
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		_ts_mouse_button(mb)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null:
		if key.pressed and not key.echo:
			ts_key(key.keycode)
		get_viewport().set_input_as_handled()


func _ts_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var id: String = canvas.widget_at(_ts_view_pos(mb.position))
	if mb.pressed:
		down_id = id
	else:
		if id != "" and id == down_id:
			ts_set_focus(id)
			ts_activate(id)
		down_id = ""


func _ts_view_pos(p: Vector2) -> Vector2:
	return ShopGame.ui_to_view(p, get_viewport().get_visible_rect().size)
