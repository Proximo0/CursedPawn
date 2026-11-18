class_name TsScreen
extends Control
## Base of the title screen and the pause menu: a 480x270 canvas in a SubViewport scaled like the room (letterboxed),
## keyboard focus (Up/Down/Enter/Esc) and mouse mapped back to the grid, and the settings panel both share.
## While visible the screen eats all input (it is a modal). Subclasses fill the ts_* hooks and never override _ready.

const SETTINGS_RECT := Rect2(110.0, 34.0, 260.0, 202.0)
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
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.z_index = 100
	_view.z_as_relative = false
	add_child(_view)
	visibility_changed.connect(_ts_on_visibility)
	settings.apply(sfx, room)
	ts_ready()
	_ts_on_visibility()


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


## Esc on the main menu.
func ts_escape_menu() -> void:
	pass


# ---------------------------------------------------------------- focus and settings

func ts_draw(c: TsCanvas) -> void:
	ts_draw_scene(c)
	if settings_open:
		_ts_draw_settings(c)
	else:
		ts_draw_menu(c)


func is_focused(id: String) -> bool:
	return focus_id == _ts_focus_of(id)


## The focusable ids on screen now (the settings panel's while it is open).
func ts_focus_ids() -> Array[String]:
	return ts_settings_ids(desktop) if settings_open else ts_menu_ids()


static func ts_settings_ids(has_fullscreen: bool) -> Array[String]:
	var out: Array[String] = [FOCUS_VOLUME, "mute", "dither"]
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
	if settings_open:
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
			if settings_open and focus_id == FOCUS_VOLUME:
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
	c.text_c(cx, r.position.y + 8.0, "SETTINGS", 11, 2)
	var y: float = r.position.y + 32.0
	var lx: float = r.position.x + 14.0
	var rx: float = r.end.x - 14.0
	# volume: label, [-], value box, [+]
	c.text(Vector2(lx, y + 5.0), "VOLUME", 15)
	c.button("vol_dec", Rect2(rx - 90.0, y, 14.0, 17.0), "-", true)
	c.frame(Rect2(rx - 74.0, y, 44.0, 17.0), "btn_off")
	c.text_c(rx - 52.0, y + 5.0, "%d%%" % settings.volume_percent(), 11, 1)
	c.button("vol_inc", Rect2(rx - 28.0, y, 14.0, 17.0), "+", true)
	_ts_focus_mark(c, FOCUS_VOLUME, Vector2(lx - 8.0, y + 5.0))
	y += 22.0
	_ts_toggle_row(c, "mute", "SOUND", "MUTED" if settings.muted else "ON", lx, rx, y)
	y += 22.0
	_ts_toggle_row(c, "dither", "DITHER", "ON" if settings.dither else "OFF", lx, rx, y)
	y += 22.0
	if desktop:
		_ts_toggle_row(c, "fullscreen", "FULLSCREEN", "ON" if settings.fullscreen else "OFF", lx, rx, y)
		y += 22.0
	c.button("reset_hints", Rect2(lx, y, r.size.x - 28.0, 17.0), "RESET TUTORIAL HINTS", true)
	_ts_focus_mark(c, "reset_hints", Vector2(lx - 8.0, y + 5.0))
	y += 19.0
	if reset_msg != "":
		c.text_c(cx, y + 1.0, reset_msg, 14, 1)
	c.button("settings_back", Rect2(cx - 40.0, r.end.y - 26.0, 80.0, 18.0), "BACK [ESC]", true, true)
	_ts_focus_mark(c, "settings_back", Vector2(cx - 50.0, r.end.y - 21.0))


func _ts_toggle_row(c: TsCanvas, id: String, label: String, value: String, lx: float, rx: float, y: float) -> void:
	c.text(Vector2(lx, y + 5.0), label, 15)
	c.button(id, Rect2(rx - 74.0, y, 74.0, 17.0), value, true)
	_ts_focus_mark(c, id, Vector2(lx - 8.0, y + 5.0))


## A small ">" marker beside the focused row, so keyboard focus reads at a glance.
func _ts_focus_mark(c: TsCanvas, id: String, at: Vector2) -> void:
	if focus_id == id:
		c.text(at, ">", 11)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or canvas == null:
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
