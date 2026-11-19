class_name TsScreen
extends Control
## Base of the title screen and the pause menu: a 640x360 canvas in a SubViewport scaled like the room (letterboxed),
## keyboard focus (Up/Down/Enter/Esc) and mouse mapped back to the grid, and the settings panel both share.
## While visible the screen eats all input (it is a modal). Subclasses fill the ts_* hooks and never override _ready.

const SETTINGS_RECT := Rect2(190.0, 46.0, 260.0, 268.0)
const FOCUS_VOLUME: String = "volume"

var settings: TsSettings = TsSettings.shared()
var sfx: SfxPlayer  ## optional: click and hover sounds, and where volume/mute are applied
var room: ShopRoom2D  ## optional: where the dither setting is applied
var web: bool = OS.has_feature("web")  ## injectable for tests; web hides Quit and Fullscreen
var desktop: bool = TsSettings.ts_is_desktop()
var settings_open: bool = false
var focus_id: String = ""
var down_id: String = ""
var reset_msg: String = ""
var canvas: TsCanvas
var profile: Object  ## optional: the player profile (RelicStore); the Ledger reads deeds and regulars from it
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
	return ts_settings_ids(desktop) if settings_open else ts_menu_ids()


static func ts_settings_ids(has_fullscreen: bool) -> Array[String]:
	var out: Array[String] = [FOCUS_VOLUME, "mute", "dither", "scares"]
	if has_fullscreen:
		out.append("fullscreen")
	out.append("reset_hints")
	out.append("settings_back")
	return out


func _ts_focus_of(id: String) -> String:
	return FOCUS_VOLUME if id == "vol_dec" or id == "vol_inc" else id


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
			if not ts_focus_ids().has(focus_id):
				focus_id = "ledger_tab_deeds"
		return
	if not settings_open:
		ts_activate_menu(id)
		return
	match id:
		"vol_dec":
			settings.step_volume(-1)
		"vol_inc":
			settings.step_volume(1)
		"mute":
			settings.muted = not settings.muted
		"dither":
			settings.dither = not settings.dither
		"scares":
			settings.scares_full = not settings.scares_full
		"fullscreen":
			settings.fullscreen = not settings.fullscreen
		"reset_hints":
			settings.reset_hints()
			reset_msg = "HINTS WILL SHOW AGAIN."
		"settings_back":
			ts_close_settings("settings")
			return
		_:
			return
	settings.apply(sfx, room)
	settings.save_player()


func ts_escape() -> void:
	if ledger_open:
		ts_close_ledger()
	elif settings_open:
		ts_close_settings("settings")
	else:
		ts_escape_menu()


func ts_key(k: int) -> bool:
	match k:
		KEY_UP:
			ts_move_focus(-1)
		KEY_DOWN:
			ts_move_focus(1)
		KEY_LEFT, KEY_RIGHT:
			if ledger_open:
				ledger.turn(-1 if k == KEY_LEFT else 1)
			elif settings_open and focus_id == FOCUS_VOLUME:
				ts_activate("vol_inc" if k == KEY_RIGHT else "vol_dec")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if focus_id != "" and focus_id != FOCUS_VOLUME:
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
	c.head_c(cx, r.position.y + 12.0, "SETTINGS", 11, 2)
	c.fill(Rect2(r.position.x + 14.0, r.position.y + 38.0, r.size.x - 28.0, 1.0), 9)
	c.fill(Rect2(r.position.x + 14.0, r.position.y + 39.0, r.size.x - 28.0, 1.0), 8)
	var y: float = r.position.y + 48.0
	var lx: float = r.position.x + 22.0
	var rx: float = r.end.x - 16.0
	# volume: label, [-], value box, [+]
	c.text(Vector2(lx, y + 6.0), "VOLUME", 15)
	c.button("vol_dec", Rect2(rx - 90.0, y, 16.0, 19.0), "-", true)
	c.frame(Rect2(rx - 72.0, y, 44.0, 19.0), "btn_off")
	c.text_c(rx - 50.0, y + 6.0, "%d%%" % settings.volume_percent(), 11, 1)
	c.button("vol_inc", Rect2(rx - 26.0, y, 16.0, 19.0), "+", true)
	_ts_focus_mark(c, FOCUS_VOLUME, Vector2(lx - 11.0, y + 6.0))
	y += 26.0
	_ts_toggle_row(c, "mute", "SOUND", "MUTED" if settings.muted else "ON", lx, rx, y)
	y += 26.0
	_ts_toggle_row(c, "dither", "DITHER", "ON" if settings.dither else "OFF", lx, rx, y)
	y += 26.0
	_ts_toggle_row(c, "scares", "SCARES", "FULL" if settings.scares_full else "GENTLE", lx, rx, y)
	y += 26.0
	if desktop:
		_ts_toggle_row(c, "fullscreen", "FULLSCREEN", "ON" if settings.fullscreen else "OFF", lx, rx, y)
		y += 26.0
	c.button("reset_hints", Rect2(lx, y, r.size.x - 38.0, 19.0), "RESET TUTORIAL HINTS", true)
	_ts_focus_mark(c, "reset_hints", Vector2(lx - 11.0, y + 6.0))
	y += 24.0
	var note: String = reset_msg
	if focus_id == "scares":
		note = "GENTLE: NO FLASHES, NO LOUD STINGERS."
	if note != "":
		c.text_c(cx, y, note, 14, 1)
	c.button("settings_back", Rect2(cx - 44.0, r.end.y - 30.0, 88.0, 20.0), "BACK [ESC]", true, true)
	_ts_focus_mark(c, "settings_back", Vector2(cx - 56.0, r.end.y - 24.0))


func _ts_toggle_row(c: TsCanvas, id: String, label: String, value: String, lx: float, rx: float, y: float) -> void:
	c.text(Vector2(lx, y + 6.0), label, 15)
	c.button(id, Rect2(rx - 78.0, y, 78.0, 19.0), value, true)
	_ts_focus_mark(c, id, Vector2(lx - 11.0, y + 6.0))


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
