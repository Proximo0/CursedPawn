class_name PauseMenu
extends TsScreen
## Esc during a run: Resume, Settings, Quit to title. Add it as a child of the game; it starts hidden, opens itself
## on Esc (unless `blocked`), pauses the tree while open (it keeps running) and emits when the player chooses.
##   var pause := PauseMenu.new(); pause.sfx = sfx; pause.room = room; add_child(pause)
##   pause.resumed.connect(...); pause.quit_to_title.connect(...)

signal resumed
signal quit_to_title

const PANEL := Rect2(150.0, 62.0, 180.0, 134.0)
const BTN_W: float = 140.0
const BTN_H: float = 18.0
const BTN_STEP: float = 24.0
const IDS: Array[String] = ["resume", "settings", "quit_title"]
const LABELS: Dictionary = {"resume": "RESUME [ESC]", "settings": "SETTINGS", "quit_title": "QUIT TO TITLE"}

var blocked: bool = false  ## the host sets this while Esc means something else (tarot stake open, a card up)
var pauses_tree: bool = true


func ts_ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	settings_open = false
	focus_id = "resume"
	visible = true
	if pauses_tree and is_inside_tree():
		get_tree().paused = true


func close() -> void:
	visible = false
	settings_open = false
	if pauses_tree and is_inside_tree():
		get_tree().paused = false


func ts_menu_ids() -> Array[String]:
	return IDS.duplicate()


func ts_activate_menu(id: String) -> void:
	match id:
		"resume":
			close()
			resumed.emit()
		"settings":
			ts_open_settings()
		"quit_title":
			close()
			quit_to_title.emit()


func ts_escape_menu() -> void:
	ts_activate_menu("resume")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and not visible and not blocked:
		open()
		get_viewport().set_input_as_handled()


func ts_draw_scene(c: TsCanvas) -> void:
	c.dim(Rect2(Vector2.ZERO, ShopGame.VIEW), 8)


func ts_draw_menu(c: TsCanvas) -> void:
	c.frame(PANEL, "panel")
	c.text_c(240.0, PANEL.position.y + 9.0, "PAUSED", 11, 3)
	var y: float = PANEL.position.y + 40.0
	for i: int in range(IDS.size()):
		var rect := Rect2(240.0 - BTN_W * 0.5, y + BTN_STEP * float(i), BTN_W, BTN_H)
		c.button(IDS[i], rect, str(LABELS[IDS[i]]), true, i == 0)
		if is_focused(IDS[i]):
			c.text(Vector2(rect.position.x - 10.0, rect.position.y + 5.0), ">", 11)
