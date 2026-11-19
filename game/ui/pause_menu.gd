class_name PauseMenu
extends TsScreen
## Esc during a run: Resume, Settings, Quit to title. Add it as a child of the game; it starts hidden, opens itself
## on Esc (unless `blocked`), pauses the tree while open (it keeps running) and emits when the player chooses.
##   var pause := PauseMenu.new(); pause.sfx = sfx; pause.room = room; add_child(pause)
##   pause.resumed.connect(...); pause.quit_to_title.connect(...)

signal resumed
signal quit_to_title

const PANEL := Rect2(220.0, 78.0, 200.0, 206.0)
const BOOK := Rect2(60.0, 16.0, 520.0, 328.0)
const BTN_W: float = 150.0
const BTN_H: float = 20.0
const BTN_STEP: float = 28.0
const IDS: Array[String] = ["resume", "grimoire", "settings", "quit_title"]
const LABELS: Dictionary = {"resume": "RESUME [ESC]", "grimoire": "GRIMOIRE", "settings": "SETTINGS", "quit_title": "QUIT TO TITLE"}

var blocked: bool = false  ## the host sets this while Esc means something else (tarot stake open, a card up)
var pauses_tree: bool = true
var known: PackedStringArray = PackedStringArray()  ## spell ids the player knows (the host sets it); the rest show greyed
var grimoire_open: bool = false
var _grim_t: float = 0.0
var _icons := UiSpellBar.new()


func ts_ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	settings_open = false
	grimoire_open = false
	focus_id = "resume"
	visible = true
	if pauses_tree and is_inside_tree():
		get_tree().paused = true


func close() -> void:
	visible = false
	settings_open = false
	grimoire_open = false
	if pauses_tree and is_inside_tree():
		get_tree().paused = false


func ts_menu_ids() -> Array[String]:
	return IDS.duplicate()


func ts_activate_menu(id: String) -> void:
	match id:
		"resume":
			close()
			resumed.emit()
		"grimoire":
			grimoire_open = true
			_grim_t = 0.0
			focus_id = "grimoire_back"
		"grimoire_back":
			grimoire_open = false
			focus_id = "grimoire"
		"settings":
			ts_open_settings()
		"quit_title":
			close()
			quit_to_title.emit()


func _process(delta: float) -> void:
	super(delta)
	if grimoire_open:
		_grim_t += delta


func ts_focus_ids() -> Array[String]:
	if grimoire_open:
		return ["grimoire_back"] as Array[String]
	return super()


func ts_escape() -> void:
	if grimoire_open:
		ts_activate_menu("grimoire_back")
	else:
		super()


func ts_draw(c: TsCanvas) -> void:
	if grimoire_open:
		ts_draw_scene(c)
		_draw_grimoire(c)
	else:
		super(c)


func ts_escape_menu() -> void:
	ts_activate_menu("resume")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and not visible and not blocked:
		open()
		get_viewport().set_input_as_handled()


func ts_draw_scene(c: TsCanvas) -> void:
	c.dim(Rect2(Vector2.ZERO, ShopGame.VIEW), 10)


func ts_draw_menu(c: TsCanvas) -> void:
	c.frame(PANEL, "panel")
	c.head_c(320.0, PANEL.position.y + 16.0, "PAUSED", 11, 2)
	c.fill(Rect2(PANEL.position.x + 16.0, PANEL.position.y + 46.0, PANEL.size.x - 32.0, 1.0), 9)
	c.fill(Rect2(PANEL.position.x + 16.0, PANEL.position.y + 47.0, PANEL.size.x - 32.0, 1.0), 8)
	var y: float = PANEL.position.y + 58.0
	for i: int in range(IDS.size()):
		var rect := Rect2(320.0 - BTN_W * 0.5, y + BTN_STEP * float(i), BTN_W, BTN_H)
		c.button(IDS[i], rect, str(LABELS[IDS[i]]), true, i == 0)
		if is_focused(IDS[i]):
			c.cursor_flame(Vector2(rect.position.x - 14.0, rect.position.y + 6.0))


## The grimoire: all six spells in two columns. Known ones show their icon, Dread cost, text and backfire line;
## unknown ones are greyed with a flickering silhouette. Entries slide in one after the other.
func _draw_grimoire(c: TsCanvas) -> void:
	c.frame(BOOK, "panel")
	var cx: float = BOOK.position.x + BOOK.size.x * 0.5
	var defs: Array[Dictionary] = UiOccult.spell_defs()
	var have: int = 0
	for d: Dictionary in defs:
		if known.has(str(d["id"])):
			have += 1
	c.head_c(cx, BOOK.position.y + 10.0, "GRIMOIRE", 11, 2)
	c.text_c(cx, BOOK.position.y + 34.0, "%d OF %d PAGES FOUND" % [have, defs.size()], 14)
	c.fill(Rect2(BOOK.position.x + 16.0, BOOK.position.y + 46.0, BOOK.size.x - 32.0, 1.0), 9)
	c.fill(Rect2(BOOK.position.x + 16.0, BOOK.position.y + 47.0, BOOK.size.x - 32.0, 1.0), 8)
	for i: int in range(defs.size()):
		var d: Dictionary = defs[i]
		var id: String = str(d["id"])
		var u: float = UiMotion.ui_out((_grim_t - 0.08 * float(i)) / 0.25)
		if u <= 0.0:
			continue
		var rc := Rect2(BOOK.position.x + 14.0 + float(i % 2) * 248.0, BOOK.position.y + 56.0 + float(i / 2) * 82.0 + floorf((1.0 - u) * 10.0), 244.0, 78.0)
		var ok: bool = known.has(id)
		c.frame(rc, "note" if ok else "btn_off")
		var icon: ImageTexture = _icons.icon(id)
		var ib := Rect2(rc.position + Vector2(8.0, 10.0), Vector2(32.0, 32.0))
		c.fill(ib.grow(2.0), 8 if ok else 0)
		var tint: Color = Color.WHITE
		if not ok:
			tint = c.c(2) if UiMotion.ui_hash(int(c.t * 9.0), i, 3) > 0.1 else c.c(1)
		c.draw_texture_rect(icon, ib, false, tint)
		if ok:
			c.text(rc.position + Vector2(48.0, 7.0), str(d["name"]).to_upper(), 12, 1, false)
			c.text(rc.position + Vector2(178.0, 7.0), "DREAD " + UiOccult.dread_text(float(d.get("dread", 0.0))), 8, 1, false)
			var lines: PackedStringArray = UiPixelFont.ui_wrap(str(d.get("text", "")), 186)
			for k: int in range(mini(lines.size(), 3)):
				c.text(rc.position + Vector2(48.0, 19.0 + float(k * UiPixelFont.LINE_H)), lines[k], 0, 1, false)
			var bf: PackedStringArray = UiPixelFont.ui_wrap("BACKFIRE: " + str(d.get("backfire", "")), 186)
			c.text(rc.position + Vector2(48.0, 51.0), bf[0] if not bf.is_empty() else "", 13, 1, false)
			if bf.size() > 1:
				c.text(rc.position + Vector2(48.0, 61.0), bf[1], 13, 1, false)
		else:
			c.text(rc.position + Vector2(48.0, 14.0), "? ? ? ? ?", 3, 1, false)
			c.text(rc.position + Vector2(48.0, 30.0), "THE PAGE IS MISSING.", 3, 1, false)
			c.text(rc.position + Vector2(48.0, 42.0), "SELLERS HIDE PAGES IN THEIR WARES.", 2, 1, false)
	var back := Rect2(cx - 44.0, BOOK.end.y - 28.0, 88.0, 20.0)
	c.button("grimoire_back", back, "BACK [ESC]", true, true)
	c.cursor_flame(Vector2(back.position.x - 14.0, back.position.y + 6.0))
