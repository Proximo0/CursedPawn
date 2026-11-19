class_name TsPad
extends RefCounted
## Gamepad and Steam Deck input as the menus see it. Every screen already answers keyboard keys; a controller event is
## turned into the key it stands for (the ui_* actions: stick and d-pad move, A accepts, B cancels, shoulders turn pages),
## so one code path serves both. `active` is true after the last input came from a controller: the focus rings and the
## button prompts show only then, and a key or the mouse hides them again.

const ACTION_KEYS: Dictionary = {
	"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT,
	"ui_accept": KEY_ENTER, "ui_cancel": KEY_ESCAPE, "ui_page_up": KEY_PAGEUP, "ui_page_down": KEY_PAGEDOWN,
}
const STICK_DEAD: float = 0.55

static var active: bool = false


static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction


## The key a controller (or ui_* action) press stands for; 0 for anything else, a release or a key/mouse event.
static func key_for(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouse or not is_pad_event(event):
		return 0
	if event.is_echo():
		return 0
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed and jb.button_index == JOY_BUTTON_START:
		return KEY_ESCAPE
	for action: Variant in ACTION_KEYS.keys():
		if event.is_action_pressed(str(action)):
			return int(ACTION_KEYS[action])
	return 0


## Notes which kind of device spoke last. Call from every screen's input handler.
static func note(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		active = false
	elif is_pad_event(event):
		var jm := event as InputEventJoypadMotion
		if jm == null or absf(jm.axis_value) > STICK_DEAD:
			active = true


## The prompt chips shown while a controller is in use: [[glyph, what], ...].
static func prompts(in_shop: bool) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	out.append(PackedStringArray(["A", "SELECT"]))
	out.append(PackedStringArray(["B", "BACK"] if not in_shop else ["START", "MENU"]))
	if in_shop:
		out.append(PackedStringArray(["X", "PASS"]))
		out.append(PackedStringArray(["Y", "LOOK"]))
	return out


## The shop-screen shortcut a controller button stands for: "pass", "look", "prev", "next" or "".
static func shop_button(event: InputEvent) -> String:
	var jb := event as InputEventJoypadButton
	if jb == null or not jb.pressed:
		return ""
	match jb.button_index:
		JOY_BUTTON_X:
			return "pass"
		JOY_BUTTON_Y:
			return "look"
		JOY_BUTTON_LEFT_SHOULDER:
			return "prev"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "next"
	return ""


## The enabled widget best placed in direction `dir` (unit vector) from the widget `from_id`, "" when none. Widgets are
## {id, rect, enabled}. With no start (or a vanished one) the first enabled widget answers.
static func next_widget(widgets: Array[Dictionary], from_id: String, dir: Vector2) -> String:
	var from := Rect2()
	var have: bool = false
	for w: Dictionary in widgets:
		if str(w["id"]) == from_id and bool(w["enabled"]):
			from = w["rect"] as Rect2
			have = true
	var best: String = ""
	var best_d: float = INF
	for w: Dictionary in widgets:
		if not bool(w["enabled"]) or str(w["id"]) == from_id:
			continue
		var r: Rect2 = w["rect"] as Rect2
		if not have:
			return str(w["id"])
		var d: Vector2 = r.get_center() - from.get_center()
		var along: float = d.dot(dir)
		if along <= 1.0:
			continue
		var cost: float = along + absf(d.cross(dir)) * 2.5
		if cost < best_d:
			best_d = cost
			best = str(w["id"])
	return best
