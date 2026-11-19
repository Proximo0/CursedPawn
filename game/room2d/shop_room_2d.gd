class_name ShopRoom2D
extends Node
## The 2D pawnshop: a side-on pixel-art room drawn into a 640x360 SubViewport (Godot Physics 2D, 60 Hz) and shown
## full screen through the 16-colour palette + Bayer dither shader. Built entirely in code. Contract:
## docs/room2d_brief.md. Same API as the old 3D ShopRoom:
##   setup(run)        fill the shelves with one prop per held item
##   apply_events(ev)  react to RunState events
##   set_dread(v)      candle flicker and green fog grow with Dread
##   wake(seed)        deterministic chaos for WAKE_SECS (physics-tick driven, so replays look the same)
## Pixels, Y down. Floor at y=230, counter top at y=170, door at the left edge, shelves wall-mounted at the back.

signal wake_finished
## A letter of speech was typed: `pitch` is a per-customer blip pitch (the lead may wire it to a sound).
signal bubble_blip(pitch: float)

const VIEW_SIZE := Vector2i(640, 360)
const WAKE_SECS: float = 4.0
const TICKS_PER_SEC: int = 60
const FLOOR_Y: float = 300.0
const COUNTER_TOP: float = 227.0  # the HUD's COUNTER_FRONT_Y
const COUNTER_X0: float = 64.0
const DOOR_RECT := Rect2(4.0, 206.0, 40.0, 94.0)
const STAND_X: float = 590.0
const STAND_Y: float = 232.0  # the whole hood and shoulders show above the counter
const WINDOW_RECT := Rect2(532.0, 70.0, 96.0, 156.0)
const DOOR_X: float = 24.0
const COUNTER_OBJ_X: float = 488.0
const TOOL_X: float = 372.0  # right of the HUD tool buttons (204..342), left of the tarot deck (400..432)
const CARD_X: float = 452.0  # beside the deck, left of the counter object
const UNIT_XS: Array[float] = [132.0, 276.0, 420.0]
const UNIT_W: float = 136.0
const UNIT_TOP: float = 44.0
const UNIT_BOTTOM: float = 218.0
const BOARD_YS: Array[float] = [98.0, 154.0, 210.0]
const SLOTS_PER_BOARD: int = 3
const SLOT_STEP: float = 42.0  # shelf item rects (ShopGame.shelf_rects) are 40x40
const OVERFLOW_X: float = 82.0
const FX_SECS: float = 1.0
const WHOLE_SCALE_MIN: float = 0.8  # = ShopGame.WHOLE_SCALE_MIN
const PROP_ZOOM: float = 1.5  ## tool props and the tarot card are drawn at 2x so they read
const CARD_FLIP_SECS: float = 0.9
const WALK_SPEED: float = 150.0
const LIGHT_RISE_PER_SEC: float = 0.6
const LIGHT_FALL_PER_SEC: float = 3.0
const RED_FADE_PER_SEC: float = 0.35
const DOOR_SPEED: float = 5.0
const SETTLE_EASY_TICKS: int = 90
const SETTLE_ALL_TICKS: int = 150
const SETTLE_SPEED: float = 30.0
const PROP_MASS: float = 1.0
const UNIT_MASS: float = 30.0
const LAYER_WORLD: int = 1
const LAYER_COUNTER: int = 2
const LAYER_PROP: int = 4
const LAYER_UNIT: int = 8
const CALM_TONE := Color(0.40, 0.40, 0.56)
const NIGHT_TONE := Color(0.06, 0.06, 0.12)
const RED_TONE := Color(0.9, 0.16, 0.15)
const AMBER_LIGHT := Color(1.0, 0.62, 0.28)
const RED_LIGHT := Color(1.0, 0.16, 0.12)
const TORCH_LIGHT := Color(1.0, 0.5, 0.2)
const MOON_LIGHT := Color(0.55, 0.66, 1.0)
const UV_COLOR := Color(0.62, 0.30, 1.0)
const CANDLES: Array[Vector2] = [Vector2(84.0, 226.0), Vector2(292.0, 226.0), Vector2(446.0, 226.0), Vector2(344.0, 40.0)]
const TORCHES: Array[Vector2] = [Vector2(54.0, 200.0), Vector2(508.0, 176.0)]
const CLOCK_POS := Vector2(34.0, 80.0)
const PORTRAIT_POSES: Array[Vector2] = [Vector2(34.0, 38.0), Vector2(510.0, 88.0)]
const CABINET_RECT := Rect2(3.0, 106.0, 54.0, 82.0)  ## the curio cabinet on the left wall: clear of the HUD (counter front y 227, door below)
const CABINET_COLS: int = 3
const CABINET_ROWS: int = 4
const CABINET_ICON: int = 16
const CABINET_MAX: int = 12
const EYES_POS := Vector2(204.0, 221.0)  # low: in the dark strip under the shelf units, just above the counter
const EYES_SCALE: float = 2.0
const RIM_COLOR := Color(1.0, 0.74, 0.36, 0.9)  ## a regular's faint warm rim light
const BEAT_TICKS: int = 54  ## the wake opens with a blackout and a flicker before the chaos (inside WAKE_SECS)
const FLASH_FROM: int = 33
const FLASH_TO: int = 46
const SILHOUETTE_X: float = 300.0
const FLAME_FPS: float = 8.0
const LAMP_POS := Vector2(500.0, 150.0)  ## the single green lamp over the counter while the Midnight Table is open
const SIGIL_POS := Vector2(300.0, 318.0)
const CHALK_POS := Vector2(COUNTER_OBJ_X, COUNTER_TOP + 8.0)
const SCRY_SECS: float = 2.4
const GLAMOUR_SECS: float = 1.6
const GLIMMER_SECS: float = 1.4
const COLLECTOR_GUTTER_SECS: float = 3.2  ## the lights gutter and a cold draft blows in when the Collector arrives
const BANISH_RING_SECS: float = 0.9
const COLLECTOR_LOOK: String = "@collector"
const TABLE_TONE := Color(0.02, 0.06, 0.04)
const LAMP_LIGHT := Color(0.35, 1.0, 0.55)
const FLAMES: Array = [
	["..o..", ".ooo.", ".oio.", ".oio.", ".oco.", "..o.."],
	[".o...", ".oo..", ".oio.", ".oio.", ".oco.", "..o.."],
	["..o..", "..o..", ".ooo.", ".oio.", ".oio.", ".oco.", "..o.."],
	["...o.", "..oo.", ".oio.", ".oio.", ".oco.", "..o.."],
]
const DUST_MOTES: int = 26
const SQUASH_TICKS: int = 3

## When false the post shader only quantises to the palette (no Bayer dither), for comparing.
var dither_enabled: bool = true:
	set(v):
		dither_enabled = v
		_apply_dither()
## Show the post-processed image full screen (false: only the SubViewport exists, for sims).
var show_screen: bool = true:
	set(v):
		show_screen = v
		if _layer != null:
			_layer.visible = v

## 0 gentle (no sudden flashes), 1 full. The UI settings pass this in; the room reads nothing else from settings.
var scare_level: int = 1

var run: RunState
var dread: float = 0.0

var _vp: SubViewport
var _layer: CanvasLayer
var _screen: TextureRect
var _shader_mat: ShaderMaterial
var _world: Node2D
var _cam: Camera2D
var _modulate: CanvasModulate
var _fx: Node2D
var _far: Node2D
var _shafts: Node2D
var _near: CanvasLayer
var _near_draw: Node2D
var _top: CanvasLayer
var _cust_occ: LightOccluder2D
var _embers: Array[CPUParticles2D] = []
## Scripted runs (shots, tests, headless) keep the parallax still so captures are repeatable.
var _scripted: bool = OS.get_cmdline_user_args().has("--scripted") or OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless"
var _fog_tex: Texture2D
var _bloom_tex: Texture2D
var _fit_win := Vector2.ZERO
var _par := Vector2.ZERO
var _far_off := Vector2.ZERO
var _near_off := Vector2.ZERO
var _glow: CanvasLayer  ## unlit layer above the lit world: flames, eyes, effects, the speech bubble
var _decor: Node2D
var _outside: Node2D
var _hall: Node2D
var _bubble: RoomBubble
var _fx_sys := RoomFx.new()
## Occult effects (grimoire spells, Midnight Table): timers count down, flags hold until the matching event ends them.
var _scry_t: float = 0.0
var _hexed: bool = false
var _glam_t: float = 0.0
var _coll_t: float = 0.0  ## seconds left of the Collector's gutter and draft
var _coll_pending: bool = false  ## collector_arrives came before his customer event
var _banish_t: float = 0.0
var _banish_at := Vector2.ZERO
var _glim_t: float = 0.0
var _sigil_on: bool = false
var _sigil_a: float = 0.0
var _sealed_on: bool = false
var _seal_a: float = 0.0
var _bf: float = 0.0
var _table: bool = false
var _table_k: float = 0.0
var _occ_acc: float = 0.0
var _occ_rng := RandomNumberGenerator.new()
var _occ_tex: Dictionary = {}
var _lamp: PointLight2D
var _lights: Array[PointLight2D] = []
var _torch_lights: Array[PointLight2D] = []
var _moon: PointLight2D
var _overlay: Sprite2D
var _overlay_on: bool = false
var _cust_frames: Array[ImageTexture] = []
var _displayed: PackedStringArray = PackedStringArray()
var _display_tex: Dictionary = {}  ## curio id -> 16x16 ImageTexture
var _rim: Sprite2D
var _regular_here: bool = false
var _regular_pending: bool = false
var _motes: Array[Dictionary] = []
var _eye_open: float = 0.0
var _flash: float = 0.0
var _art_cache: Dictionary = {}
var _prev_v: Dictionary = {}
var _squash: Dictionary = {}
var _watch_k: float = 0.0
var _walk_from: float = 0.0
var _walk_to: float = 0.0
var _walk_dur: float = 1.0
var _card_trail: float = 0.0
var _door_sprite: Sprite2D
var _seller_here: bool = false
var _tool_pos := Vector2(TOOL_X, 200.0)
var _card_pos := Vector2(CARD_X, 200.0)
var _door_open: float = 0.0
var _door_target: float = 0.0
var _door_fast: bool = false
var _units: Array[RigidBody2D] = []
var _slots: Array[Dictionary] = []  ## {pos: Vector2 (board point under the object), unit: int}
var _slot_used: Dictionary = {}  ## slot index -> uid
var _props: Dictionary = {}  ## uid -> {uid, name, category, id, body, sprite, slot}
var _slides: Array[Dictionary] = []
var _shards: Array[RigidBody2D] = []
var _doomed: RigidBody2D

var _customer: Sprite2D
var _look_id: String = ""
var _cust_state: String = "none"  ## none, enter, here, leave
var _cust_x: float = DOOR_X
var _walk_t: float = 0.0
var _line: String = ""
var _counter_obj: Sprite2D
var _counter_cat: String = ""
var _counter_item: Dictionary = {}  ## {id, category} of the object on the counter
var _tool_sprite: Sprite2D
var _fx_kind: String = ""
var _fx_t: float = 0.0
var _fx_tell: String = ""  ## the last inspected tell; the Pendulum shows "cursed" or "clean"
var _card: Sprite2D
var _card_name: String = ""
var _card_t: float = -1.0

var _t: float = 0.0
var _level: float = 1.0
var _level_target: float = 1.0
var _red: float = 0.0
var _shake: float = 0.0
var _wake_tick: int = -1
var _settle_tick: int = -1  ## ticks since the wake ended; bodies are frozen where they lie once they are slow
var _wake_plan: Array[Dictionary] = []
var _plan_i: int = 0
var _wake_rng := RandomNumberGenerator.new()
var _wakes_done: int = 0
var _tex_cache: Dictionary = {}


func _init() -> void:
	_occ_rng.seed = 90210
	name = "ShopRoom2D"
	_build_view()
	_rebuild_world()


func _build_view() -> void:
	_vp = SubViewport.new()
	_vp.name = "RoomViewport2D"
	_vp.size = VIEW_SIZE
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_disable_input = true
	add_child(_vp)
	_layer = CanvasLayer.new()
	_layer.layer = -10
	_layer.visible = show_screen
	add_child(_layer)
	_screen = TextureRect.new()
	_screen.texture = _vp.get_texture()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = RoomPalette.make_shader()
	_screen.material = _shader_mat
	_layer.add_child(_screen)
	_apply_dither()


## Same maths as ShopGame.ui_scale / ui_rect (copied, so the room does not depend on the UI scripts and still compiles in
## engine-free shot and test runs): a whole-number scale when it keeps WHOLE_SCALE_MIN of the fit, else the plain fit.
static func fit_scale(win: Vector2) -> float:
	var fit: float = minf(win.x / float(VIEW_SIZE.x), win.y / float(VIEW_SIZE.y))
	if fit < 1.0:
		return fit
	var whole: float = floorf(fit + 0.0001)
	return whole if whole >= fit * WHOLE_SCALE_MIN else fit


static func fit_rect(win: Vector2) -> Rect2:
	var sz: Vector2 = Vector2(VIEW_SIZE) * fit_scale(win)
	return Rect2(((win - sz) * 0.5).floor(), sz)


## Places the picture exactly where the HUD grid sits (whole-number scale when it keeps 80% of the fit).
func _fit_screen() -> void:
	if _screen == null or not is_inside_tree():
		return
	var win: Vector2 = get_viewport().get_visible_rect().size
	if win == _fit_win or win.x <= 0.0:
		return
	_fit_win = win
	var r: Rect2 = fit_rect(win)
	_screen.position = r.position
	_screen.size = r.size


func _apply_dither() -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("dither_on", dither_enabled)


# ---------------------------------------------------------------- public API

## Fills the shelves with one prop per held item and shows the current customer. Resets everything visual.
func setup(run_in: RunState) -> void:
	run = run_in
	_rebuild_world()
	if run == null:
		return
	for item: Dictionary in run.inventory:
		_add_prop(int(item["uid"]), str(item["name"]), str(item["category"]), str(item.get("id", item["name"])), false)
	set_dread(run.dread)
	if not run.customer.is_empty() and not run.is_over():
		var cat: String = ""
		var oname: String = ""
		if str(run.customer.get("kind", "")) == RunState.SELLER:
			var it: Dictionary = run.customer.get("item", {}) as Dictionary
			cat = str(it.get("category", ""))
			oname = str(it.get("name", ""))
		var tid: String = str(run.customer.get("type", ""))
		if bool(run.customer.get("boss", false)) or tid == "collector_boss":
			_set_collector_look()
		else:
			_set_customer_look(tid)
		_line = ""
		_seller_here = str(run.customer.get("kind", "")) == RunState.SELLER
		_cust_start_enter(oname, cat)
		_cust_state = "here"
		_cust_x = STAND_X
		_show_counter_object()
		_place_customer()


func set_dread(v: float) -> void:
	dread = maxf(v, 0.0)


## 0..1.5, Dread as a fraction of the wake threshold.
## Sets the curios shown in the glass cabinet on the left wall (up to CABINET_MAX, in order). The UI calls it at run start.
func set_displayed(ids: PackedStringArray) -> void:
	_displayed = PackedStringArray()
	for id: String in ids:
		if _displayed.size() >= CABINET_MAX:
			break
		_displayed.append(id)
	if _decor != null:
		_decor.queue_redraw()


func displayed_ids() -> PackedStringArray:
	return _displayed


func regular_here() -> bool:
	return _regular_here


func _cabinet_icon(id: String) -> Texture2D:
	if not _display_tex.has(id):
		var img: Image = SpriteKit.curio_icon(id).get_image()
		img.resize(CABINET_ICON, CABINET_ICON, Image.INTERPOLATE_NEAREST)
		_display_tex[id] = ImageTexture.create_from_image(img)
	return _display_tex[id] as Texture2D


## The glass-fronted curio cabinet: dark wood and a brass trim, four velvet-lined shelves of three, a soft glint per piece.
func _draw_cabinet(pal: PackedColorArray) -> void:
	var r: Rect2 = CABINET_RECT
	_decor.draw_rect(Rect2(r.position - Vector2.ONE, r.size + Vector2(2.0, 2.0)), pal[0])
	_decor.draw_rect(r, pal[8])
	_decor.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), pal[9])
	_decor.draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y), pal[9])
	_decor.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y), pal[0])
	var inner := Rect2(r.position.x + 3.0, r.position.y + 5.0, r.size.x - 6.0, r.size.y - 8.0)
	_decor.draw_rect(Rect2(inner.position.x - 1.0, inner.position.y - 1.0, inner.size.x + 2.0, inner.size.y + 2.0), pal[10])  # brass trim
	_decor.draw_rect(inner, pal[0])
	_decor.draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, inner.size.y * 0.5), pal[1])  # velvet back, darker at the bottom
	var cell_h: float = inner.size.y / float(CABINET_ROWS)
	var cell_w: float = inner.size.x / float(CABINET_COLS)
	_decor.draw_rect(Rect2(r.position.x + 10.0, r.position.y + 1.0, r.size.x - 20.0, 3.0), pal[10])  # a brass pediment plate
	_decor.draw_rect(Rect2(r.position.x + 10.0, r.position.y + 1.0, r.size.x - 20.0, 1.0), pal[11])
	for row: int in range(CABINET_ROWS):
		var by: float = inner.position.y + cell_h * float(row + 1)
		_decor.draw_rect(Rect2(inner.position.x, by - 3.0, inner.size.x, 3.0), pal[9])
		_decor.draw_rect(Rect2(inner.position.x, by - 3.0, inner.size.x, 1.0), pal[10])
		for col: int in range(CABINET_COLS):
			var i: int = row * CABINET_COLS + col
			var cx: float = inner.position.x + cell_w * (float(col) + 0.5)
			var top := Vector2(roundf(cx - float(CABINET_ICON) * 0.5), roundf(by - 3.0 - float(CABINET_ICON)))
			if i >= _displayed.size():
				_decor.draw_rect(Rect2(top.x + 4.0, top.y + 10.0, 8.0, 1.0), pal[2])  # an empty place on the velvet
				continue
			_decor.draw_texture(_cabinet_icon(_displayed[i]), top)
			# a soft glint that wanders over each piece, out of step with its neighbours
			var ph: float = fposmod(_t * 0.55 + float(i) * 0.37, 3.0)
			if ph < 0.6:
				var a: float = sin(ph / 0.6 * PI)
				var gp := Vector2(top.x + 3.0 + floorf(float(i % 3) * 4.0), top.y + 3.0 + floorf(float(i % 4) * 2.0))
				var gc: Color = pal[15]
				gc.a = a * 0.9
				_decor.draw_rect(Rect2(gp.x, gp.y, 1.0, 1.0), gc)
				gc.a = a * 0.45
				_decor.draw_rect(Rect2(gp.x - 1.0, gp.y, 3.0, 1.0), gc)
				_decor.draw_rect(Rect2(gp.x, gp.y - 1.0, 1.0, 3.0), gc)
	var glass: Color = pal[14]  # the glass: a pale diagonal sheen and a frosted edge
	glass.a = 0.07
	_decor.draw_rect(inner, glass)
	glass.a = 0.12
	for k: int in range(3):
		_decor.draw_line(inner.position + Vector2(4.0 + float(k) * 3.0, inner.size.y - 4.0), inner.position + Vector2(inner.size.x - 6.0 + float(k) * 3.0, 4.0), glass, 1.0)
	_decor.draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 1.0), Color(pal[15], 0.25))
	_decor.draw_rect(Rect2(r.position.x + 20.0, r.end.y - 2.0, 14.0, 1.0), pal[10])  # the lock plate
	_decor.draw_rect(Rect2(r.position.x + 26.0, r.end.y - 3.0, 2.0, 2.0), pal[11])


func dread_norm() -> float:
	return clampf(dread / maxf(Tuning.shared().wake_threshold, 0.1), 0.0, 1.5)


func apply_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match str(e.get("e", "")):
			"night_start":
				_level_target = 1.0
				_hide_card()
				_table = false
				_sealed_on = false
				_hexed = false
			"customer":
				_hide_card()
				_hexed = false
				if _sigil_on:
					_sigil_on = false
					_fx_sys.emit("ash", SIGIL_POS + Vector2(0.0, -6.0), 10)
				_seller_here = str(e.get("kind", "")) == RunState.SELLER
				_regular_here = str(e.get("regular", "")) != "" or _regular_pending
				_regular_pending = false
				var oname: String = ""
				var cat: String = ""
				if str(e.get("kind", "")) == RunState.SELLER:
					oname = str(e.get("name", ""))
					cat = _category_of_name(oname)
				var tid: String = str(e.get("tid", ""))
				if bool(e.get("boss", false)) or tid == "collector_boss" or _coll_pending:
					_coll_pending = false
					_set_collector_look()
				else:
					_set_customer_look(tid)
				_line = str(e.get("line", ""))
				if _line == "":
					_line = str(_look_row(tid).get("line", ""))
				_cust_start_enter(oname, cat)
			"passed", "left":
				_hexed = false
				_cust_start_leave()
			"bought":
				_hexed = false
				_on_bought(e)
				_cust_start_leave()
			"sold":
				_hexed = false
				_on_sold(e)
				_cust_start_leave()
			"regular":
				if _cust_state == "enter" or _cust_state == "here":
					_regular_here = true
				else:
					_regular_pending = true
			"scry_reveal":
				_scry_t = SCRY_SECS
			"hexed":
				_hexed = true
			"glamoured":
				_glam_t = GLAMOUR_SECS
			"banished":
				_on_banished(e)
			"collector_arrives":
				_on_collector_arrives()
			"summoned":
				_sigil_on = true
				_fx_sys.emit("ash", SIGIL_POS, 14)
			"sealed":
				_sealed_on = true
			"backfire":
				_on_backfire()
			"found_hint":
				_glim_t = GLIMMER_SECS
			"table_open":
				_table = true
				_hexed = false
				_hide_card()
			"inspected":
				_fx_tell = str(e.get("tell", ""))
				_start_fx(str(e.get("tool", "")))
				if str(e.get("tell", "")) != "" and str(e.get("tell", "")) != "clean":
					_show_overlay()
			"wager":
				_start_card(str(e.get("card", "")))
			"wake":
				_on_wake_event(e)
			"night_end":
				_hexed = false
				_sealed_on = false
				_cust_start_leave()
				_level = minf(_level, 0.2)
				_level_target = 0.2
			"run_lost":
				_table = false
				_sealed_on = false
				_hexed = false
				_cust_start_leave()
				_level = minf(_level, 0.25)
				_level_target = 0.06
			"run_won":
				_table = false
				_sealed_on = false
				_hexed = false
				_cust_start_leave()
				_level_target = 1.35
			_:
				pass


## The Collector walks in: the candles gutter nearly out, a cold draft of pale particles runs in from the door, and if a
## customer is already at the door or counter, he takes their place. Otherwise his customer event dresses him.
func _on_collector_arrives() -> void:
	_coll_t = COLLECTOR_GUTTER_SECS
	_fx_sys.emit("draft", Vector2(DOOR_X + 6.0, STAND_Y - 20.0), 24)
	if _cust_state == "enter" or _cust_state == "here":
		_set_collector_look()
	else:
		_coll_pending = true


## Test hook: true while the Collector's sprite is the customer.
func collector_here() -> bool:
	return _look_id == COLLECTOR_LOOK


## 0..1, how far the Collector's arrival has guttered the lights (0 when he is not arriving).
func collector_gutter() -> float:
	return clampf(_coll_t / COLLECTOR_GUTTER_SECS, 0.0, 1.0)


func _set_collector_look() -> void:
	if _customer == null or _look_id == COLLECTOR_LOOK:
		return
	_look_id = COLLECTOR_LOOK
	_cust_frames = SpriteKit.collector_frames()
	_apply_customer_frame(0)


func _on_banished(e: Dictionary) -> void:
	var at := Vector2(float(UNIT_XS[1]), float(BOARD_YS[1]) - 14.0)
	var uid: int = int(e.get("uid", -1))
	if _props.has(uid):
		var rec: Dictionary = _props[uid]
		var body: RigidBody2D = rec["body"] as RigidBody2D
		at = body.position + Vector2(0.0, 6.0)
		_remove_prop(uid)
	_fx_sys.emit("inksmoke", at, 36)
	_fx_sys.emit("ash", at + Vector2(0.0, -8.0), 12)
	_fx_sys.emit("sparkle", at + Vector2(0.0, -4.0), 8)
	_banish_t = BANISH_RING_SECS
	_banish_at = at


## A backfire: a red flash and a shake. Gentle scares keep a soft, slow wash and a tiny shake, never a hard flash.
func _on_backfire() -> void:
	_bf = 1.0
	_shake = maxf(_shake, 3.5 if scare_level != 0 else 1.2)


func _reset_occult() -> void:
	_scry_t = 0.0
	_hexed = false
	_glam_t = 0.0
	_glim_t = 0.0
	_coll_t = 0.0
	_coll_pending = false
	_banish_t = 0.0
	_sigil_on = false
	_sigil_a = 0.0
	_sealed_on = false
	_seal_a = 0.0
	_bf = 0.0
	_table = false
	_table_k = 0.0


## Per-frame timers for the occult effects: sparkles on the shelves, a glimmer on the counter object, fades.
func _update_occult(delta: float) -> void:
	_scry_t = maxf(_scry_t - delta, 0.0)
	_bf = maxf(_bf - delta * (2.2 if scare_level != 0 else 0.9), 0.0)
	_sigil_a = move_toward(_sigil_a, 1.0 if _sigil_on else 0.0, delta * 1.5)
	_seal_a = move_toward(_seal_a, 1.0 if _sealed_on else 0.0, delta * 1.2)
	_table_k = move_toward(_table_k, 1.0 if _table else 0.0, delta * 1.3)
	_banish_t = maxf(_banish_t - delta, 0.0)
	_coll_t = maxf(_coll_t - delta, 0.0)
	_occ_acc += delta
	if _occ_acc < 0.08:
		return
	_occ_acc = 0.0
	if _glam_t > 0.0:
		_glam_t = maxf(_glam_t - 0.08, 0.0)
		for _gi: int in range(2):
			var ui: int = _occ_rng.randi_range(0, UNIT_XS.size() - 1)
			var gx: float = UNIT_XS[ui] + _occ_rng.randf_range(-UNIT_W * 0.5 + 8.0, UNIT_W * 0.5 - 8.0)
			var gy: float = BOARD_YS[_occ_rng.randi_range(0, BOARD_YS.size() - 1)] - _occ_rng.randf_range(4.0, 30.0)
			_fx_sys.emit("gold", Vector2(gx, gy), 5)
	if _coll_t > 0.0:  # a cold draft along the floor from the door
		_fx_sys.emit("draft", Vector2(DOOR_X + 6.0, _occ_rng.randf_range(STAND_Y - 70.0, STAND_Y + 40.0)), 6)
	if _glim_t > 0.0 and _counter_obj != null and _counter_obj.visible:
		_glim_t = maxf(_glim_t - 0.08, 0.0)
		_fx_sys.emit("glimmer", _counter_obj.position + Vector2(_occ_rng.randf_range(-14.0, 14.0), _occ_rng.randf_range(-16.0, 14.0)), 4)
	elif _glim_t > 0.0:
		_glim_t = 0.0


## Overall light, scaled right down while the Midnight Table is open (the one green lamp stays).
func _lv() -> float:
	return clampf(_level, 0.0, 1.0) * (1.0 - 0.95 * _table_k)


## Deterministic chaos for about WAKE_SECS: shelf props are unfrozen and thrown, one shelf tears off the wall and
## tips, the lights die and come back red, the door slams, the screen shakes. Same seed and props, same result.
func wake(seed_value: int) -> void:
	_wake_rng.seed = seed_value
	_wake_plan.clear()
	_plan_i = 0
	_wake_tick = 0
	_settle_tick = -1
	_wakes_done += 1
	_slides.clear()
	if _cust_state != "none":
		_finish_leave()
	_hide_fx()
	_reset_occult()
	var bodies: Array[RigidBody2D] = []
	for uid: Variant in _props:
		bodies.append((_props[uid] as Dictionary)["body"] as RigidBody2D)
	if _doomed != null:
		bodies.append(_doomed)
	for body: RigidBody2D in bodies:
		body.freeze = false
		var delay: float = _wake_rng.randf_range(0.95, 2.6)
		var vx: float = _wake_rng.randf_range(70.0, 240.0) * (1.0 if _wake_rng.randf() < 0.5 else -1.0)
		var vy: float = _wake_rng.randf_range(180.0, 380.0)
		var spin: float = _wake_rng.randf_range(-9.0, 9.0)
		var skip: float = _wake_rng.randf()
		if skip < 0.1 and body != _doomed:
			continue
		_plan_add(int(delay * TICKS_PER_SEC), "shove", body, Vector2(vx, -vy) * PROP_MASS, spin)
	var pick: int = _wake_rng.randi_range(0, maxi(_units.size() - 1, 0))
	_plan_add(int(1.6 * TICKS_PER_SEC), "topple", null, Vector2(float(pick), 0.0), 0.0)
	_plan_add(int(1.25 * TICKS_PER_SEC), "slam", null, Vector2.ZERO, 0.0)
	_plan_add(BEAT_TICKS, "burst", null, Vector2.ZERO, 0.0)
	if _doomed != null:
		var shards: Array = []
		for i: int in range(10):
			shards.append({"v": Vector2(_wake_rng.randf_range(-140.0, 140.0), -_wake_rng.randf_range(80.0, 260.0)),
				"c": _wake_rng.randi_range(0, 3)})
		_plan_add(int(2.1 * TICKS_PER_SEC), "shatter", _doomed, Vector2.ZERO, 0.0, shards)
	_plan_add(int(WAKE_SECS * TICKS_PER_SEC), "end", null, Vector2.ZERO, 0.0)
	_wake_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["t"]) < int(b["t"]) or (int(a["t"]) == int(b["t"]) and int(a["n"]) < int(b["n"])))
	_door_target = 0.0
	_door_fast = false
	_shake = 0.0
	_flash = 0.0
	_bubble.hide_now()
	_overlay_on = false
	_prev_v.clear()
	_squash.clear()


func is_waking() -> bool:
	return _wake_tick >= 0


func prop_count() -> int:
	return _props.size()


func prop_bodies() -> Array[RigidBody2D]:
	var out: Array[RigidBody2D] = []
	for uid: Variant in _props:
		out.append((_props[uid] as Dictionary)["body"] as RigidBody2D)
	return out


## Props, the shelf units and any shards: everything the physics moves.
func all_bodies() -> Array[RigidBody2D]:
	var out: Array[RigidBody2D] = prop_bodies()
	out.append_array(_units)
	out.append_array(_shards)
	if _doomed != null:
		out.append(_doomed)
	return out


func prop_names() -> PackedStringArray:
	var out := PackedStringArray()
	for uid: Variant in _props:
		out.append(str((_props[uid] as Dictionary)["name"]))
	return out


func customer_state() -> String:
	return _cust_state


func customer_look_id() -> String:
	return _look_id


## Pixel height of the customer sprite (taller types stand taller behind the counter).
func customer_height() -> int:
	if _customer == null or _customer.texture == null:
		return 0
	return _customer.texture.get_height()


## How clear a horizontal span (x0..x1, e.g. the HUD's tarot deck) is of the walking customer: 0 while the figure
## overlaps it during a walk, 1 when the customer is standing, absent or far enough away, easing in between.
func customer_clearance(x0: float, x1: float) -> float:
	if _cust_state != "enter" and _cust_state != "leave":
		return 1.0
	var half: float = 0.5 * float(_customer.texture.get_width()) if _customer.texture != null else 32.0
	return span_clearance(_cust_x, half, x0, x1)


## Pure form of customer_clearance: a figure centred at cx with half width `half` against the span x0..x1.
static func span_clearance(cx: float, half: float, x0: float, x1: float) -> float:
	var d: float = maxf(x0 - cx, cx - x1)  # distance of the centre outside the span (negative inside)
	return clampf((d - (half - 16.0)) / 16.0, 0.0, 1.0)


func bubble_text() -> String:
	return _bubble.shown_text()


func has_card() -> bool:
	return _card != null and _card.visible


func fx_kind() -> String:
	return _fx_kind


func light_level() -> float:
	return _level


func viewport() -> SubViewport:
	return _vp


## Test hook: "hexed", "sealed", "sigil" (summon sigil waiting for its customer), "table" (Midnight Table lighting).
func occult_state(which: String) -> bool:
	match which:
		"hexed":
			return _hexed
		"sealed":
			return _sealed_on
		"sigil":
			return _sigil_on
		"table":
			return _table
	return false


func shake_amount() -> float:
	return _shake


## The largest linear speed among all moving bodies (px/s); 0 when there are none.
func max_body_speed() -> float:
	var m: float = 0.0
	for b: RigidBody2D in all_bodies():
		m = maxf(m, b.linear_velocity.length())
	return m


## Jumps animations to their ends (customer arrived or gone, effects done, lights settled). For tests and shots.
func settle_visuals() -> void:
	if _cust_state == "enter":
		_cust_state = "here"
		_cust_x = STAND_X
		_show_counter_object()
		_show_bubble()
	elif _cust_state == "leave":
		_finish_leave()
	_bubble.finish_typing()
	_level = _level_target
	_slides.clear()
	_place_customer()


# ---------------------------------------------------------------- world building

func _rebuild_world() -> void:
	_slides.clear()
	if _world != null:
		_vp.remove_child(_world)
		_world.free()
	_units.clear()
	_slots.clear()
	_slot_used.clear()
	_props.clear()
	_slides.clear()
	_shards.clear()
	_lights.clear()
	_torch_lights.clear()
	_prev_v.clear()
	_squash.clear()
	_fx_sys.clear()
	_doomed = null
	_wake_tick = -1
	_settle_tick = -1
	_wake_plan.clear()
	_shake = 0.0
	_reset_occult()
	_red = 0.0
	_flash = 0.0
	_eye_open = 0.0
	_watch_k = 0.0
	_overlay_on = false
	_level = 1.0
	_level_target = 1.0
	_fx_kind = ""
	_card_t = -1.0
	_cust_state = "none"
	_seller_here = false
	_look_id = ""
	_line = ""
	_door_open = 0.0
	_door_target = 0.0
	_door_fast = false
	_world = Node2D.new()
	_world.name = "World2D"
	_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vp.add_child(_world)
	_cam = Camera2D.new()
	_cam.position = Vector2(VIEW_SIZE) * 0.5
	_cam.enabled = true
	_world.add_child(_cam)
	_modulate = CanvasModulate.new()
	_modulate.color = CALM_TONE
	_world.add_child(_modulate)
	_glow = CanvasLayer.new()
	_glow.name = "Glow"
	_glow.layer = 5
	_glow.follow_viewport_enabled = true
	_world.add_child(_glow)
	_far = Node2D.new()
	_far.name = "FarLayer"
	_world.add_child(_far)
	_embers.clear()
	_build_near()
	_build_shafts()
	_build_backdrop()
	_build_bounds()
	_build_units()
	_build_counter()
	_build_customer()
	_build_overlays()
	_build_lights()
	_build_torches()
	_build_motes()
	_apply_ambient()


func _tex(kind: String) -> Texture2D:
	if not _tex_cache.has(kind):
		_tex_cache[kind] = SpriteKit.tile_texture(kind)
	return _tex_cache[kind] as Texture2D


## A horror prop texture, or null while the sprite kit only has its flat placeholder (the room then draws its own).
func _art(kind: String) -> Texture2D:
	if _art_cache.has(kind):
		return _art_cache[kind] as Texture2D
	var res: Texture2D = null
	var tex: ImageTexture = SpriteKit.horror_texture(kind)
	if tex != null:
		var img: Image = tex.get_image()
		var first: Color = img.get_pixel(0, 0)
		for y: int in range(0, img.get_height(), 2):
			for x: int in range(0, img.get_width(), 2):
				if not img.get_pixel(x, y).is_equal_approx(first):
					res = tex
					break
			if res != null:
				break
	_art_cache[kind] = res
	return res


func _tile(kind: String, rect: Rect2, z: int, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = RoomNormals.canvas_texture("tile:" + kind, _tex(kind), 1.4, true)
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.position = rect.position
	s.z_index = z
	parent.add_child(s)
	return s


func _rect(rect: Rect2, c: Color, z: int, parent: Node) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = c
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _canvas_node(z: int, drawer: Callable, parent: Node) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.draw.connect(drawer)
	parent.add_child(n)
	return n


func _build_backdrop() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var vw: float = float(VIEW_SIZE.x)
	_tile("wall", Rect2(-12.0, -12.0, vw + 24.0, FLOOR_Y + 12.0), -10, _far)
	_tile("floor", Rect2(-12.0, FLOOR_Y, vw + 24.0, float(VIEW_SIZE.y) - FLOOR_Y + 12.0), -10, _far)
	_rect(Rect2(0.0, FLOOR_Y, vw, 1.0), pal[0], -9, _far)
	# moonlit window behind the customer's spot, so a dark hood reads against it
	var w: Rect2 = WINDOW_RECT
	_rect(Rect2(w.position - Vector2(3.0, 3.0), w.size + Vector2(6.0, 3.0)), pal[0], -8, _far)
	_rect(w, pal[2], -7, _far)
	_rect(Rect2(w.position.x, w.position.y + 78.0, w.size.x, w.size.y - 78.0), pal[3], -7, _far)
	_outside = _canvas_node(-6, _draw_outside, _far)
	_rect(Rect2(w.position.x + w.size.x * 0.5 - 2.0, w.position.y, 3.0, w.size.y), pal[0], -5, _far)
	_rect(Rect2(w.position.x, w.position.y + 52.0, w.size.x, 3.0), pal[0], -5, _far)
	_rect(Rect2(w.position.x - 5.0, w.position.y + w.size.y - 4.0, w.size.x + 10.0, 4.0), pal[8], -5, _far)
	# door: a dark hallway glimpse behind the door leaf, hinged on its left edge
	_rect(Rect2(DOOR_RECT.position - Vector2(3.0, 3.0), DOOR_RECT.size + Vector2(6.0, 3.0)), pal[0], -8, _far)
	_hall = _canvas_node(-7, _draw_hall, _far)
	_door_sprite = _tile("door", DOOR_RECT, -6, _far)
	_decor = _canvas_node(-4, _draw_decor, _far)


func _body(layer: int, mask: int, mode: int = RigidBody2D.FREEZE_MODE_STATIC) -> RigidBody2D:
	var b := RigidBody2D.new()
	b.collision_layer = layer
	b.collision_mask = mask
	b.freeze_mode = mode as RigidBody2D.FreezeMode
	b.can_sleep = true
	b.contact_monitor = false
	return b


func _static_box(rect: Rect2, layer: int) -> StaticBody2D:
	var sb := StaticBody2D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	sb.add_child(cs)
	sb.position = rect.position + rect.size * 0.5
	_world.add_child(sb)
	return sb


func _build_bounds() -> void:
	var vw: float = float(VIEW_SIZE.x)
	_static_box(Rect2(-40.0, FLOOR_Y, vw + 80.0, 40.0), LAYER_WORLD)
	_static_box(Rect2(-40.0, -60.0, vw + 80.0, 60.0), LAYER_WORLD)
	_static_box(Rect2(-40.0, -60.0, 40.0, 500.0), LAYER_WORLD)
	_static_box(Rect2(vw, -60.0, 40.0, 500.0), LAYER_WORLD)


func _build_units() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var h: float = UNIT_BOTTOM - UNIT_TOP
	for ui: int in range(UNIT_XS.size()):
		var u: RigidBody2D = _body(LAYER_UNIT, LAYER_WORLD | LAYER_COUNTER | LAYER_PROP)
		u.freeze = true
		u.mass = UNIT_MASS
		u.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
		u.center_of_mass = Vector2.ZERO
		u.linear_damp = 0.4
		u.angular_damp = 1.0
		u.position = Vector2(UNIT_XS[ui], UNIT_TOP + h * 0.5)
		u.z_index = 1
		u.set_meta("unit", ui)
		# visuals (relative to the body centre)
		_rect(Rect2(-UNIT_W * 0.5, -h * 0.5, UNIT_W, h), pal[1], 0, u)
		_tile("shelf", Rect2(-UNIT_W * 0.5, -h * 0.5, 4.0, h), 1, u)
		_tile("shelf", Rect2(UNIT_W * 0.5 - 4.0, -h * 0.5, 4.0, h), 1, u)
		for by: float in BOARD_YS:
			var ly: float = by - (UNIT_TOP + h * 0.5)
			_tile("shelf", Rect2(-UNIT_W * 0.5, ly, UNIT_W, 5.0), 1, u)
			_rect(Rect2(-UNIT_W * 0.5 + 4.0, ly + 5.0, UNIT_W - 8.0, 9.0), Color(0.0, 0.0, 0.0, 0.5), 1, u)  # deep shadow under the board
			_add_box_shape(u, Rect2(-UNIT_W * 0.5, ly, UNIT_W, 5.0))
			_occluder(_slab(Rect2(-UNIT_W * 0.5, ly, UNIT_W, 5.0)), u)
			for si: int in range(SLOTS_PER_BOARD):
				_slots.append({"pos": Vector2(UNIT_XS[ui] - UNIT_W * 0.5 + 8.0 + 21.0 + SLOT_STEP * float(si), by), "unit": ui})
		_add_box_shape(u, Rect2(-UNIT_W * 0.5, -h * 0.5, 4.0, h))
		_add_box_shape(u, Rect2(UNIT_W * 0.5 - 4.0, -h * 0.5, 4.0, h))
		_add_box_shape(u, Rect2(-UNIT_W * 0.5, -h * 0.5, UNIT_W, 4.0))
		_world.add_child(u)
		_units.append(u)
	# slot order: middle board first, then top, then bottom, so a few props fill the readable boards
	var ordered: Array[Dictionary] = []
	for bi: int in [1, 0, 2]:
		for ui: int in range(UNIT_XS.size()):
			for si: int in range(SLOTS_PER_BOARD):
				ordered.append(_slots[ui * BOARD_YS.size() * SLOTS_PER_BOARD + bi * SLOTS_PER_BOARD + si])
	_slots = ordered


func _add_box_shape(body: Node, rect: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.position + rect.size * 0.5
	body.add_child(cs)


func _build_counter() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var cw: float = float(VIEW_SIZE.x) - COUNTER_X0
	_static_box(Rect2(COUNTER_X0, COUNTER_TOP, cw, FLOOR_Y - COUNTER_TOP + 40.0), LAYER_COUNTER)
	_occluder(_slab(Rect2(COUNTER_X0, COUNTER_TOP + 2.0, cw, 10.0)), _world)
	_tile("counter", Rect2(COUNTER_X0, COUNTER_TOP, cw, FLOOR_Y - COUNTER_TOP), 4, _world)
	_rect(Rect2(COUNTER_X0, COUNTER_TOP, cw, 2.0), pal[0], 5, _world)
	_rect(Rect2(COUNTER_X0, COUNTER_TOP + 2.0, cw, 3.0), pal[9], 5, _world)
	_rect(Rect2(COUNTER_X0 - 1.0, COUNTER_TOP, 1.0, 74.0), pal[0], 5, _world)
	_rect(Rect2(COUNTER_X0, COUNTER_TOP + 5.0, cw, 10.0), Color(0.0, 0.0, 0.0, 0.45), 5, _world)  # shadow under the lip


func _build_customer() -> void:
	_customer = Sprite2D.new()
	_customer.centered = false
	_customer.z_index = 3
	_customer.visible = false
	_world.add_child(_customer)
	_cust_occ = LightOccluder2D.new()
	_cust_occ.occluder = OccluderPolygon2D.new()
	_customer.add_child(_cust_occ)
	_rim = Sprite2D.new()  # the same figure one pixel up and left, in unshaded amber, peeking out behind it
	_rim.centered = false
	_rim.z_index = -1
	_rim.visible = false
	var rim_mat := CanvasItemMaterial.new()
	rim_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_rim.material = rim_mat
	_customer.add_child(_rim)
	_counter_obj = Sprite2D.new()
	_counter_obj.z_index = 6
	_counter_obj.visible = false
	_world.add_child(_counter_obj)
	_tool_sprite = Sprite2D.new()
	_tool_sprite.z_index = 6
	_tool_sprite.visible = false
	_world.add_child(_tool_sprite)
	_card = Sprite2D.new()
	_card.z_index = 6
	_card.visible = false
	_world.add_child(_card)
	_overlay = Sprite2D.new()  # the faint wrongness over a cursed object lives on the unlit layer so it glows
	_overlay.visible = false
	_glow.add_child(_overlay)
	_set_customer_texture({})


func _build_overlays() -> void:
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	_glow.add_child(_fx)
	_bubble = RoomBubble.new()
	_bubble.fx = _fx_sys
	_bubble.blip.connect(_on_bubble_blip)
	_top.add_child(_bubble)


func _on_bubble_blip(pitch: float) -> void:
	bubble_blip.emit(pitch)


func _build_lights() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	grad.colors = PackedColorArray([Color.WHITE, Color(0.42, 0.42, 0.42), Color.BLACK])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	for c: Vector2 in CANDLES:
		var l := PointLight2D.new()
		l.texture = gt
		l.texture_scale = 2.7
		l.position = c + Vector2(0.0, -8.0)
		l.color = AMBER_LIGHT
		l.energy = 1.0
		l.height = 16.0
		_world.add_child(l)
		_lights.append(l)
	for c: Vector2 in TORCHES:
		var tl := PointLight2D.new()
		tl.texture = gt
		tl.texture_scale = 4.2
		tl.position = c + Vector2(0.0, -12.0)
		tl.color = TORCH_LIGHT
		tl.energy = 2.2
		tl.height = 26.0
		tl.shadow_enabled = true
		tl.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		tl.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
		_world.add_child(tl)
		_torch_lights.append(tl)
	_moon = PointLight2D.new()  # cold window light
	_moon.texture = gt
	_moon.texture_scale = 3.4
	_moon.position = WINDOW_RECT.position + Vector2(WINDOW_RECT.size.x * 0.5, 70.0)
	_moon.color = MOON_LIGHT
	_moon.height = 40.0
	_moon.energy = 0.9
	_world.add_child(_moon)
	_lamp = PointLight2D.new()  # the Midnight Table lamp
	_lamp.texture = gt
	_lamp.texture_scale = 3.8
	_lamp.position = LAMP_POS + Vector2(0.0, 26.0)
	_lamp.color = LAMP_LIGHT
	_lamp.energy = 0.0
	_lamp.height = 30.0
	_world.add_child(_lamp)


func _build_motes() -> void:
	_motes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i: int in range(DUST_MOTES):
		var c: Vector2 = CANDLES[i % 3] + Vector2(0.0, -10.0)
		_motes.append({"c": c, "ph": rng.randf_range(0.0, TAU), "r": rng.randf_range(14.0, 58.0), "sp": rng.randf_range(0.4, 1.0), "col": 11})
	for i: int in range(10):  # motes turning in the moon shafts
		_motes.append({"c": WINDOW_RECT.position + Vector2(-60.0, 110.0), "ph": rng.randf_range(0.0, TAU), "r": rng.randf_range(20.0, 80.0),
			"sp": rng.randf_range(0.3, 0.8), "col": 4})


# ---------------------------------------------------------------- props

func _look_row(tid: String) -> Dictionary:
	if run != null and run.catalog != null:
		for t: Dictionary in run.catalog.customers:
			if str(t.get("id", "")) == tid:
				return t
	return {}


func _category_of_name(item_name: String) -> String:
	if run != null and run.catalog != null:
		for o: Dictionary in run.catalog.objects:
			if str(o["name"]) == item_name:
				return str(o["category"])
	return ""


func _id_of_name(item_name: String) -> String:
	if run != null and run.catalog != null:
		for o: Dictionary in run.catalog.objects:
			if str(o["name"]) == item_name:
				return str(o["id"])
	return item_name


func _free_slot() -> int:
	for i: int in range(_slots.size()):
		if not _slot_used.has(i):
			return i
	return -1


func _slot_pos(slot: int, overflow_i: int) -> Vector2:
	if slot >= 0:
		return (_slots[slot]["pos"] as Vector2)
	return Vector2(OVERFLOW_X + float(overflow_i % 6) * 18.0, COUNTER_TOP - float(overflow_i / 6) * 20.0)


func _add_prop(uid: int, pname: String, category: String, id: String, slide: bool) -> void:
	if _props.has(uid):
		return
	var tex: ImageTexture = SpriteKit.object_texture(id, category)
	var slot: int = _free_slot()
	var spot: Vector2 = _slot_pos(slot, _props.size())
	var b: RigidBody2D = _body(LAYER_PROP, LAYER_WORLD | LAYER_COUNTER | LAYER_PROP | LAYER_UNIT)
	b.mass = PROP_MASS
	b.freeze = true
	b.linear_damp = 0.15
	b.angular_damp = 0.5
	var pb: PhysicsMaterial = PhysicsMaterial.new()
	pb.friction = 0.8
	pb.bounce = 0.25
	b.physics_material_override = pb
	b.z_index = 2
	var sp := Sprite2D.new()
	sp.texture = RoomNormals.canvas_texture("obj:%s:%s" % [id, category], tex, 1.2, false)
	b.add_child(sp)
	var half: Vector2 = Vector2(maxf(float(tex.get_width()) - 2.0, 6.0), maxf(float(tex.get_height()) - 2.0, 6.0))
	_add_box_shape(b, Rect2(-half * 0.5, half))
	var rest: Vector2 = spot + Vector2(0.0, -float(tex.get_height()) * 0.5)
	b.position = rest
	b.set_meta("unit", int(_slots[slot]["unit"]) if slot >= 0 else -1)
	_world.add_child(b)
	if slot >= 0:
		_slot_used[slot] = uid
	_props[uid] = {"uid": uid, "name": pname, "category": category, "id": id, "body": b, "sprite": sp, "slot": slot}
	if slide:
		b.position = Vector2(COUNTER_OBJ_X, COUNTER_TOP - float(tex.get_height()) * 0.5)
		_slides.append({"body": b, "from": b.position, "to": rest, "t": 0.0})


func _remove_prop(uid: int) -> Dictionary:
	if not _props.has(uid):
		return {}
	var rec: Dictionary = _props[uid]
	_props.erase(uid)
	if int(rec["slot"]) >= 0:
		_slot_used.erase(int(rec["slot"]))
	var b: RigidBody2D = rec["body"] as RigidBody2D
	_world.remove_child(b)
	b.free()
	return rec


func _on_bought(e: Dictionary) -> void:
	var uid: int = int(e.get("uid", -1))
	var cat: String = ""
	var id: String = ""
	if run != null:
		for item: Dictionary in run.inventory:
			if int(item["uid"]) == uid:
				cat = str(item["category"])
				id = str(item.get("id", ""))
	if cat == "":
		cat = _counter_cat if _counter_cat != "" else _category_of_name(str(e.get("name", "")))
	if id == "":
		id = str(_counter_item.get("id", _id_of_name(str(e.get("name", "?")))))
	_add_prop(uid, str(e.get("name", "?")), cat, id, true)
	_hide_counter_object()


func _on_sold(e: Dictionary) -> void:
	var uid: int = int(e.get("uid", -1))
	var rec: Dictionary = _remove_prop(uid)
	if not rec.is_empty():
		_counter_item = {"id": rec["id"], "category": rec["category"]}
		_counter_cat = str(rec["category"])
	else:
		_counter_cat = _category_of_name(str(e.get("name", "")))
		_counter_item = {"id": _id_of_name(str(e.get("name", ""))), "category": _counter_cat}
	_show_counter_object()
	_fx_sys.emit("sparkle", _counter_obj.position, 16)  # coin sparkle burst


func _update_slides(delta: float) -> void:
	for i: int in range(_slides.size() - 1, -1, -1):
		var s: Dictionary = _slides[i]
		if not is_instance_valid(s["body"]) or _wake_tick >= 0:  # check before the cast: a sold prop is freed
			_slides.remove_at(i)
			continue
		var body: RigidBody2D = s["body"] as RigidBody2D
		if body == null:
			_slides.remove_at(i)
			continue
		var t: float = minf(float(s["t"]) + delta / 0.5, 1.0)
		s["t"] = t
		var p: Vector2 = (s["from"] as Vector2).lerp(s["to"] as Vector2, _ease(t))
		p.y -= sin(t * PI) * 24.0
		body.position = p
		if t >= 1.0:
			body.position = s["to"] as Vector2
			_slides.remove_at(i)


# ---------------------------------------------------------------- customer and counter object

func _set_customer_texture(look: Dictionary) -> void:
	_cust_frames = SpriteKit.customer_frames(look)
	if _cust_frames.is_empty():
		_cust_frames = [SpriteKit.customer_texture(look)]
	_apply_customer_frame(0)


func _apply_customer_frame(i: int) -> void:
	var tex: ImageTexture = _cust_frames[clampi(i, 0, _cust_frames.size() - 1)]
	_customer.texture = tex
	_customer.offset = Vector2(-float(tex.get_width()) * 0.5, -float(tex.get_height()))
	if _rim != null:
		_rim.texture = tex
		_rim.offset = _customer.offset
	if _customer.get_meta("occ_h", -1) != tex.get_height():
		_customer.set_meta("occ_h", tex.get_height())
		_fit_customer_occluder()


## Idle animation at about 7 fps: mostly the rest frame, a blink and a head tilt now and then.
func _idle_frame_index() -> int:
	var n: int = _cust_frames.size()
	if n <= 1:
		return 0
	var tick: int = int(_t * 7.0) % 36
	if tick == 14 or tick == 15:
		return mini(1, n - 1)
	if tick >= 24 and tick <= 29:
		return mini(2, n - 1)
	if tick == 30 or tick == 31:
		return mini(3, n - 1)
	return 0


## Dresses the figure as customer type `tid` (unchanged if same type).
func _set_customer_look(tid: String) -> void:
	if tid == _look_id or _customer == null:
		return
	_look_id = tid
	_set_customer_texture(_look_row(tid))


func _start_walk(from_x: float, to_x: float) -> void:
	_walk_from = from_x
	_walk_to = to_x
	_walk_dur = maxf(absf(to_x - from_x) / WALK_SPEED, 0.05)
	_walk_t = 0.0


func _cust_start_enter(oname: String, category: String) -> void:
	if _cust_state == "leave":
		_finish_leave()
	_hide_counter_object()
	_bubble.hide_now()
	_counter_cat = category
	_counter_item = {}
	if oname != "":
		_counter_item = {"id": _id_of_name(oname), "category": category}
	_cust_state = "enter"
	_cust_x = DOOR_X
	_start_walk(DOOR_X, STAND_X)
	_door_target = 1.0
	_door_fast = false
	_customer.visible = true
	_place_customer()


func _cust_start_leave() -> void:
	if _cust_state == "none":
		return
	_cust_state = "leave"
	_start_walk(_cust_x, DOOR_X)
	_bubble.close()
	_door_target = 1.0
	_door_fast = false
	var h: float = float(customer_height())
	for i: int in range(3):  # ink-smoke puffs where they stood
		_fx_sys.emit("smoke", Vector2(_cust_x, STAND_Y - h * (0.2 + 0.3 * float(i))), 3)


func _finish_leave() -> void:
	_cust_state = "none"
	_regular_here = false
	_customer.visible = false
	_bubble.hide_now()
	_hide_counter_object()
	_door_target = 0.0


func _place_customer() -> void:
	var bob: float = 0.0
	if _cust_state == "enter" or _cust_state == "leave":
		bob = absf(sin(_walk_t * 11.0)) * 3.0
	elif _cust_frames.size() <= 1:
		bob = roundf(sin(_t * 1.6) * 0.5 + 0.5)  # a one-pixel breath when there are no idle frames
	_customer.position = Vector2(roundf(_cust_x), STAND_Y - bob)
	_customer.flip_h = _cust_state == "leave"
	if _rim != null:
		_rim.flip_h = _customer.flip_h
		_rim.position = Vector2(2.0 if _customer.flip_h else -2.0, -1.0)
		_rim.visible = _regular_here and _customer.visible
		var pulse: float = 0.8 + 0.2 * sin(_t * 2.4)
		_rim.modulate = Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, RIM_COLOR.a * pulse)


func _show_counter_object() -> void:
	if _counter_item.is_empty():
		_counter_obj.visible = false
		return
	var tex: ImageTexture = SpriteKit.object_texture(str(_counter_item["id"]), str(_counter_item["category"]))
	_counter_obj.texture = RoomNormals.canvas_texture("obj:%s:%s" % [str(_counter_item["id"]), str(_counter_item["category"])], tex, 1.2, false)
	_counter_obj.position = Vector2(COUNTER_OBJ_X, COUNTER_TOP - float(tex.get_height()) * 0.5)
	_counter_obj.rotation = 0.0
	_counter_obj.visible = true


func _hide_counter_object() -> void:
	_counter_obj.visible = false
	_overlay_on = false
	_overlay.visible = false


func _show_overlay() -> void:
	if _counter_item.is_empty() or not _seller_here or not _counter_obj.visible:
		return
	_overlay.texture = SpriteKit.object_cursed_overlay(str(_counter_item["id"]))
	_overlay_on = true


func _show_bubble() -> void:
	if _line == "" or _cust_state != "here":
		return
	var hh: int = absi(_look_id.hash())
	_bubble.pitch = 0.75 + float(hh % 9) * 0.06
	_bubble.blip_every = 2 + (hh / 7) % 2
	_bubble.open(_line, Vector2(_cust_x, STAND_Y - float(customer_height()) - 3.0), float(VIEW_SIZE.x))


# ---------------------------------------------------------------- tool effects and card

func _start_fx(tool: String) -> void:
	if not Catalog.TOOLS.has(tool) and tool != "pendulum":
		return
	_fx_kind = tool
	_fx_t = 0.0
	var tex: ImageTexture = SpriteKit.tool_texture(tool)
	_tool_sprite.texture = tex
	_tool_pos = Vector2(TOOL_X, COUNTER_TOP - float(tex.get_height()) * PROP_ZOOM * 0.5 + 10.0)
	_tool_sprite.position = _tool_pos
	_tool_sprite.scale = Vector2.ONE * PROP_ZOOM
	_tool_sprite.visible = true


func _hide_fx() -> void:
	_fx_kind = ""
	_tool_sprite.visible = false
	_counter_obj.rotation = 0.0


func _start_card(card: String) -> void:
	_card_name = card
	_card_t = 0.0
	var tex: ImageTexture = SpriteKit.card_texture(card, false)
	_card.texture = tex
	_card_pos = Vector2(CARD_X, COUNTER_TOP - float(tex.get_height()) * PROP_ZOOM * 0.5 + 8.0)
	_card.position = _card_pos
	_card.scale = Vector2.ONE * PROP_ZOOM
	_card.visible = true


func _hide_card() -> void:
	_card_t = -1.0
	_card.visible = false


func _ease(k: float) -> float:
	var c: float = clampf(k, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _update_card(delta: float) -> void:
	if _card_t < 0.0:
		return
	_card_t += delta
	var k: float = clampf(_card_t / CARD_FLIP_SECS, 0.0, 1.0)
	var e: float = _ease(k)
	_card.texture = SpriteKit.card_texture(_card_name, e >= 0.5)
	_card.scale = Vector2(maxf(absf(cos(e * PI)), 0.04), 1.0) * PROP_ZOOM
	_card.position = _card_pos + Vector2(0.0, -sin(e * PI) * 14.0)
	if k < 1.0:  # a spark trail off the card's edges as it turns
		_card_trail += delta
		var half: float = float(_card.texture.get_width()) * 0.5 * _card.scale.x
		while _card_trail >= 0.025:
			_card_trail -= 0.025
			var side: float = 1.0 if int(_card_t * 40.0) % 2 == 0 else -1.0
			_fx_sys.emit("trail", _card.position + Vector2(side * (half + 1.0), sin(_card_t * 23.0) * 18.0), 1)


func _update_fx(delta: float) -> void:
	if _fx_kind == "":
		return
	_fx_t += delta
	var k: float = clampf(_fx_t / FX_SECS, 0.0, 1.0)
	if _fx_kind == "scale" and _counter_obj.visible:
		_counter_obj.rotation = sin(_fx_t * 14.0) * 0.22 * (1.0 - _ease(k))
	_tool_sprite.position = _tool_pos + Vector2(0.0, sin(_fx_t * 6.0) * 1.5)
	if _fx_t >= FX_SECS:
		_hide_fx()


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_t += delta
	_update_customer(delta)
	_update_slides(delta)
	_update_fx(delta)
	_update_card(delta)
	_update_door(delta)
	if _wake_tick < 0:
		_update_light_level(delta)
	_bubble.advance(delta)
	_fx_sys.update(delta)
	_update_occult(delta)
	_update_eyes(delta)
	_update_watcher(delta)
	_update_overlay()
	_update_parallax(delta)
	_fit_screen()
	_apply_ambient()
	_fx.queue_redraw()
	_decor.queue_redraw()
	_outside.queue_redraw()
	_hall.queue_redraw()


func _update_customer(delta: float) -> void:
	match _cust_state:
		"enter":
			_walk_t += delta
			var k: float = clampf(_walk_t / _walk_dur, 0.0, 1.0)
			_cust_x = lerpf(_walk_from, _walk_to, _ease(k))
			if k >= 1.0:
				_cust_x = STAND_X
				_cust_state = "here"
				_show_counter_object()
				_show_bubble()
				_door_target = 0.0
			_place_customer()
		"leave":
			_walk_t += delta
			var k2: float = clampf(_walk_t / _walk_dur, 0.0, 1.0)
			_cust_x = lerpf(_walk_from, _walk_to, _ease(k2))
			if k2 >= 1.0:
				_finish_leave()
			else:
				_place_customer()
		"here":
			_apply_customer_frame(_idle_frame_index())
			_place_customer()
	if _cust_state == "enter" and _cust_x > 80.0:
		_door_target = 0.0


func _update_door(delta: float) -> void:
	var rate: float = DOOR_SPEED * (4.0 if _door_fast else 1.0)
	_door_open = move_toward(_door_open, _door_target, rate * delta)
	var rattle: float = 0.0
	if dread_norm() >= 0.9 and _wake_tick < 0:  # something tries the handle from the other side
		var cyc: float = fposmod(_t, 7.0)
		if cyc < 0.7:
			rattle = roundf(sin(_t * 70.0) * 1.5 * (1.0 - cyc / 0.7))
	_door_sprite.position.x = DOOR_RECT.position.x + rattle
	_door_sprite.scale.x = lerpf(1.0, 0.12, _ease(_door_open))


func _update_light_level(delta: float) -> void:
	if _level < _level_target:
		_level = minf(_level + LIGHT_RISE_PER_SEC * delta, _level_target)
	elif _level > _level_target:
		_level = maxf(_level - LIGHT_FALL_PER_SEC * delta, _level_target)
	_red = maxf(_red - RED_FADE_PER_SEC * delta, 0.0)


## Eyes in the dark corner open at Dread 0.5 and shut while the customer speaks.
func _update_eyes(delta: float) -> void:
	var want: float = 0.0
	if dread_norm() >= 0.5 and _wake_tick < 0 and not _bubble.is_speaking():
		want = 1.0
	_eye_open = move_toward(_eye_open, want, delta * 2.2)


func _update_overlay() -> void:
	_overlay.visible = _overlay_on and _counter_obj.visible
	if _overlay.visible:
		_overlay.position = _counter_obj.position
		_overlay.rotation = _counter_obj.rotation
		_overlay.modulate.a = 0.55 + 0.3 * sin(_t * 2.2)


## At Dread 0.7 one shelf object slowly turns to face the counter.
func _update_watcher(delta: float) -> void:
	var best: int = -1
	for uid: Variant in _props:
		if best < 0 or int(uid) < best:
			best = int(uid)
	var want: float = 1.0 if (dread_norm() >= 0.7 and _wake_tick < 0) else 0.0
	_watch_k = move_toward(_watch_k, want, delta * 0.7)
	if best < 0:
		return
	var sp: Sprite2D = (_props[best] as Dictionary)["sprite"] as Sprite2D
	if _wake_tick >= 0:
		return
	var e: float = _ease(_watch_k)
	sp.flip_h = e > 0.5
	sp.rotation = e * (0.2 + sin(_t * 1.7) * 0.015)


func _apply_ambient() -> void:
	var lv: float = _lv()
	var tone: Color = NIGHT_TONE.lerp(CALM_TONE, lv)
	if _level > 1.0:
		tone = CALM_TONE * (1.0 + (_level - 1.0) * 2.2)
		tone.a = 1.0
	tone = tone.lerp(RED_TONE * 0.7, clampf(_red, 0.0, 1.0) * 0.95)
	tone = tone.lerp(TABLE_TONE, _table_k * 0.8)
	tone.a = 1.0
	_modulate.color = tone
	_lamp.energy = 3.4 * _table_k * (1.0 + sin(_t * 7.0) * 0.04 + sin(_t * 19.0) * 0.03)
	var n: float = dread_norm()
	var gut: float = clampf((n - 0.3) / 0.3, 0.0, 1.0)  # candles gutter from 0.3
	var i: int = 0
	for l: PointLight2D in _lights:
		var flick: float = 1.0 + (sin(_t * (9.0 + float(i) * 2.3) + float(i)) * 0.5 + sin(_t * (23.0 + float(i) * 5.1)) * 0.5) * (0.06 + 0.2 * n)
		flick *= 1.0 - 0.6 * gut * _ease((sin(_t * (3.1 + float(i) * 0.7) + float(i) * 2.0) - 0.7) / 0.3)
		if n > 1.0 and sin(_t * (31.0 + float(i))) > 0.9:
			flick *= 0.3
		if _coll_t > 0.0:  # the Collector: flames flutter low and nearly die
			var ck: float = clampf(minf(collector_gutter() * 5.0, 1.0), 0.0, 1.0)
			flick *= lerpf(1.0, 0.1 + 0.3 * absf(sin(_t * (13.0 + float(i) * 3.0))), ck)
		l.color = AMBER_LIGHT.lerp(RED_LIGHT, clampf(_red, 0.0, 1.0))
		l.energy = lv * 2.0 * flick * (1.0 + 1.6 * _red)
		i += 1
	var ti: int = 0
	for tl: PointLight2D in _torch_lights:
		var tf: float = 1.0 + (sin(_t * (11.0 + float(ti) * 3.1)) * 0.5 + sin(_t * (27.0 + float(ti) * 4.3)) * 0.5) * (0.09 + 0.16 * n)
		tf *= 1.0 - 0.5 * gut * _ease((sin(_t * (2.3 + float(ti)) + 1.0) - 0.75) / 0.25)
		tl.color = TORCH_LIGHT.lerp(RED_LIGHT, clampf(_red, 0.0, 1.0))
		tl.energy = lv * 2.4 * tf * (1.0 + 1.2 * _red)
		tl.position = TORCHES[ti] + Vector2(0.0, -12.0) + _far_off
		_embers[ti].emitting = lv > 0.25
		_embers[ti].position = TORCHES[ti] + Vector2(0.0, -16.0) + _far_off
		ti += 1
	_update_shafts(lv)
	var hs: float = lv * (1.0 - clampf(_red, 0.0, 1.0))
	for hi: int in range(3):
		var hp: Vector2 = (TORCHES[hi] + Vector2(0.0, -12.0) + _far_off) if hi < 2 else (CANDLES[3] + Vector2(0.0, -12.0))
		_shader_mat.set_shader_parameter("heat%d" % hi, Vector4(hp.x / float(VIEW_SIZE.x), hp.y / float(VIEW_SIZE.y), 0.07, hs))
	_moon.energy = lv * (1.15 + 0.1 * sin(_t * 0.4)) * (1.0 - clampf(_red, 0.0, 1.0) * 0.8)
	_shader_mat.set_shader_parameter("vignette", 0.32 + 0.4 * clampf(n, 0.0, 1.2))


# ---------------------------------------------------------------- the wake (physics-tick driven)

func _on_wake_event(e: Dictionary) -> void:
	var broke: String = str(e.get("broke", ""))
	_doomed = null
	if broke != "":
		for uid: Variant in _props:
			if str((_props[uid] as Dictionary)["name"]) == broke:
				var rec: Dictionary = _props[uid]
				_props.erase(uid)
				if int(rec["slot"]) >= 0:
					_slot_used.erase(int(rec["slot"]))
				_doomed = rec["body"] as RigidBody2D
				break
	var seed_value: int = int(e.get("night", 0)) * 7919 + int(round(float(e.get("dread", 0.0)) * 100.0)) * 31
	if run != null:
		seed_value += run.seed_used * 104729
	wake(seed_value)


func _plan_add(tick: int, kind: String, body: Variant, v: Vector2, w: float, shards: Array = []) -> void:
	_wake_plan.append({"t": tick, "n": _wake_plan.size(), "k": kind, "body": body, "v": v, "w": w, "shards": shards})


func _physics_process(_delta: float) -> void:
	_shake = maxf(_shake * 0.93 - 0.02, 0.0)
	if _wake_tick >= 0:
		_wake_step()
	elif _settle_tick >= 0:
		_settle_step()
		_squash_step()
	var off := Vector2.ZERO
	if _shake > 0.4:
		var tk: float = float(Engine.get_physics_frames())
		off = Vector2(roundf(sin(tk * 2.9) * _shake), roundf(cos(tk * 3.7) * _shake))
	_cam.offset = off


func _wake_step() -> void:
	while _plan_i < _wake_plan.size() and int(_wake_plan[_plan_i]["t"]) <= _wake_tick:
		var step: Dictionary = _wake_plan[_plan_i]
		_plan_i += 1
		match str(step["k"]):
			"shove":
				# check before the cast: casting a freed body is an error (a shatter can free it mid-plan)
				var body: RigidBody2D = step["body"] as RigidBody2D if is_instance_valid(step["body"]) else null
				if body != null:
					body.collision_mask = LAYER_WORLD | LAYER_COUNTER | LAYER_PROP  # the poltergeist pulls it through the boards
					body.sleeping = false
					body.apply_central_impulse(step["v"] as Vector2)
					body.angular_velocity = float(step["w"])
					_shake = maxf(_shake, 1.5)
			"topple":
				_topple(int((step["v"] as Vector2).x))
			"burst":  # the beat is over: the door flies open and the room erupts
				_door_target = 1.0
				_door_fast = true
				_shake = maxf(_shake, 4.0)
			"slam":
				_door_target = 0.0
				_shake = maxf(_shake, 5.0)
			"shatter":
				if is_instance_valid(step["body"]):
					_shatter(step["body"] as RigidBody2D, step["shards"] as Array)
			"end":
				_end_wake()
				return
	_wake_tick += 1
	_squash_step()
	var t: float = float(_wake_tick) / float(TICKS_PER_SEC)
	if _wake_tick <= BEAT_TICKS:  # blackout, then a single red flicker showing who stands behind the counter
		_level = 0.0
		_red = 0.0
		_flash = _wake_flash(_wake_tick)
		return
	_flash = 0.0
	var t2: float = t - float(BEAT_TICKS) / float(TICKS_PER_SEC)
	_level = 0.05
	_red = clampf(t2 * 3.0, 0.0, 1.0) * (0.8 + 0.2 * sin(t * 11.0))
	_shake = maxf(_shake, 1.2)


## Flash strength 0..1 for the silhouette beat. Full scares strobe hard; gentle shows it dimly without any flash.
func _wake_flash(tick: int) -> float:
	if scare_level == 0:
		if tick < FLASH_FROM or tick >= BEAT_TICKS:
			return 0.0
		var k: float = sin(float(tick - FLASH_FROM) / float(BEAT_TICKS - FLASH_FROM) * PI)
		return clampf(k * 1.6, 0.0, 1.0) * 0.9  # a plateau, not a spike
	if tick < FLASH_FROM or tick >= FLASH_TO:
		return 0.0
	return 1.0 if (tick - FLASH_FROM) % 4 < 2 else 0.0


## Two-frame squash on impact: a prop that lands hard flattens for a moment and puffs dust.
func _squash_step() -> void:
	for uid: Variant in _props:
		var rec: Dictionary = _props[uid]
		var b: RigidBody2D = rec["body"] as RigidBody2D
		var id: int = b.get_instance_id()
		var v: Vector2 = b.linear_velocity
		var pv: Vector2 = _prev_v.get(id, Vector2.ZERO) as Vector2
		var sp: Sprite2D = rec["sprite"] as Sprite2D
		if pv.length() > 110.0 and (v - pv).length() > 120.0 and not _squash.has(id):
			_squash[id] = {"sp": sp, "t": SQUASH_TICKS * 2, "h": float(sp.texture.get_height())}
			_fx_sys.emit("dust", b.position + Vector2(0.0, float(sp.texture.get_height()) * 0.5), 4)
		_prev_v[id] = v
	for id: Variant in _squash.keys():
		var q: Dictionary = _squash[id]
		var spr: Sprite2D = q["sp"] as Sprite2D
		if not is_instance_valid(spr):
			_squash.erase(id)
			continue
		q["t"] = int(q["t"]) - 1
		var tl: int = int(q["t"])
		if tl > SQUASH_TICKS:
			spr.scale = Vector2(1.3, 0.7)
		elif tl > 0:
			spr.scale = Vector2(1.12, 0.9)
		else:
			spr.scale = Vector2.ONE
			_squash.erase(id)
		spr.position.y = float(q["h"]) * 0.5 * (1.0 - spr.scale.y)


func _settle_step() -> void:
	_settle_tick += 1
	if _settle_tick != SETTLE_EASY_TICKS and _settle_tick != SETTLE_ALL_TICKS:
		return
	for b: RigidBody2D in all_bodies():
		if _settle_tick == SETTLE_ALL_TICKS or b.linear_velocity.length() < SETTLE_SPEED:
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.freeze = true
	if _settle_tick == SETTLE_ALL_TICKS:
		_settle_tick = -1


func _topple(index: int) -> void:
	if index < 0 or index >= _units.size():
		return
	var u: RigidBody2D = _units[index]
	u.freeze = false
	u.sleeping = false
	u.collision_mask = LAYER_WORLD | LAYER_COUNTER  # the heavy unit never crushes props into the counter
	for pb: RigidBody2D in prop_bodies():
		pb.collision_mask = LAYER_WORLD | LAYER_COUNTER | LAYER_PROP
	var dir: float = 1.0 if _wake_rng.randf() < 0.5 else -1.0
	u.apply_impulse(Vector2(dir * 900.0, -300.0), Vector2(0.0, -50.0))
	u.angular_velocity = dir * 1.6
	_shake = maxf(_shake, 6.0)


func _shatter(body: RigidBody2D, shards: Array) -> void:
	if not is_instance_valid(body):
		return
	var at: Vector2 = body.position
	var pal: PackedColorArray = RoomPalette.colors()
	var cols: Array[Color] = [pal[14], pal[15], pal[11], pal[9]]
	for s: Dictionary in shards:
		var sh: RigidBody2D = _body(LAYER_PROP, LAYER_WORLD | LAYER_COUNTER)
		sh.mass = 0.1
		sh.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		sh.position = at
		sh.linear_velocity = s["v"] as Vector2
		sh.linear_damp = 0.2
		sh.angular_damp = 2.0
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.3
		sh.physics_material_override = pm
		_add_box_shape(sh, Rect2(-1.5, -1.5, 3.0, 3.0))
		var vis := ColorRect.new()
		vis.size = Vector2(3.0, 3.0)
		vis.position = Vector2(-1.5, -1.5)
		vis.color = cols[int(s["c"])]
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.add_child(vis)
		sh.z_index = 3
		_world.add_child(sh)
		_shards.append(sh)
	if body == _doomed:
		_doomed = null
	_world.remove_child(body)
	body.free()
	_shake = maxf(_shake, 4.0)


func _end_wake() -> void:
	_wake_tick = -1
	_settle_tick = 0
	_level_target = 1.0
	_door_target = 0.0
	_door_fast = false
	_flash = 0.0
	for b: RigidBody2D in all_bodies():
		b.linear_damp = maxf(b.linear_damp, 1.5)
		b.angular_damp = maxf(b.angular_damp, 3.0)
	wake_finished.emit()




# ---------------------------------------------------------------- depth: parallax, haze, light shafts

## Far layer drifts with the mouse, the near layer against it, both with a slow camera breathe. Whole pixels only.
func _update_parallax(delta: float) -> void:
	var m := Vector2.ZERO
	if is_inside_tree() and not _scripted:
		var vp: Viewport = get_viewport()
		var sz: Vector2 = vp.get_visible_rect().size
		if sz.x > 0.0 and sz.y > 0.0:
			var mp: Vector2 = vp.get_mouse_position()
			m = Vector2(clampf((mp.x / sz.x - 0.5) * 2.0, -1.0, 1.0), clampf((mp.y / sz.y - 0.5) * 2.0, -1.0, 1.0))
	_par = _par.lerp(m, 1.0 - exp(-delta * 3.0))
	var br := Vector2(sin(_t * 0.31) * 0.35, cos(_t * 0.23) * 0.25)
	var p: Vector2 = _par + br
	_far_off = Vector2(roundf(p.x * 2.0), roundf(p.y * 1.0))
	_near_off = Vector2(roundf(-p.x * 7.0), roundf(-p.y * 4.0))
	_far.position = _far_off
	_shafts.position = _far_off
	_near_draw.position = _near_off


func _build_shafts() -> void:
	_shafts = Node2D.new()
	_shafts.name = "Shafts"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shafts.material = mat
	_glow.add_child(_shafts)
	_glow.move_child(_shafts, 0)
	var w: Rect2 = WINDOW_RECT
	var panes: Array[Vector2] = [Vector2(w.position.x + 6.0, w.position.x + 44.0), Vector2(w.position.x + 52.0, w.position.x + 90.0)]
	var i: int = 0
	for pn: Vector2 in panes:
		for k: int in range(2):  # two overlapping beams per pane, different lengths
			var poly := Polygon2D.new()
			var y0: float = w.position.y + 12.0 + float(k) * 62.0
			var run_x: float = 170.0 + float(k) * 60.0
			var drop: float = 120.0 + float(k) * 20.0
			poly.polygon = PackedVector2Array([Vector2(pn.x, y0), Vector2(pn.y, y0 + 8.0), Vector2(pn.y - run_x, y0 + 8.0 + drop),
				Vector2(pn.x - run_x, y0 + drop)])
			poly.vertex_colors = PackedColorArray([Color(0.30, 0.36, 0.62, 0.5), Color(0.30, 0.36, 0.62, 0.5), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)])
			poly.set_meta("phase", float(i) * 1.7)
			_shafts.add_child(poly)
			i += 1


func _update_shafts(lv: float) -> void:
	var i: int = 0
	for c: Node in _shafts.get_children():
		var ph: float = float((c as Node2D).get_meta("phase", 0.0))
		(c as Node2D).modulate.a = lv * (0.6 + 0.4 * sin(_t * 0.45 + ph)) * (1.0 - clampf(_red, 0.0, 1.0))
		i += 1


func _build_near() -> void:
	_near = CanvasLayer.new()
	_near.name = "Near"
	_near.layer = 6
	_near.follow_viewport_enabled = true
	_world.add_child(_near)
	_near_draw = _canvas_node(0, _draw_near, _near)
	_top = CanvasLayer.new()
	_top.name = "Top"
	_top.layer = 8
	_top.follow_viewport_enabled = true
	_world.add_child(_top)


func _build_torches() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	for c: Vector2 in TORCHES:
		var em := CPUParticles2D.new()
		em.amount = 8
		em.lifetime = 1.3
		em.preprocess = 1.0
		em.fixed_fps = 20
		em.local_coords = false
		em.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		em.emission_sphere_radius = 3.0
		em.direction = Vector2(0.0, -1.0)
		em.spread = 30.0
		em.gravity = Vector2(0.0, -8.0)
		em.initial_velocity_min = 10.0
		em.initial_velocity_max = 26.0
		em.scale_amount_min = 1.0
		em.scale_amount_max = 2.0
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([pal[11], pal[10], Color(pal[13].r, pal[13].g, pal[13].b, 0.0)])
		em.color_ramp = g
		em.set("use_fixed_seed", true)
		em.set("seed", 1234)
		em.position = c + Vector2(0.0, -16.0)
		_glow.add_child(em)
		_embers.append(em)


func _occluder(poly: PackedVector2Array, parent: Node) -> void:
	var occ := LightOccluder2D.new()
	var op := OccluderPolygon2D.new()
	op.polygon = poly
	occ.occluder = op
	parent.add_child(occ)


func _slab(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## The customer's hood casts a shadow of its own: a rough trapezoid sized from the current texture.
func _fit_customer_occluder() -> void:
	if _cust_occ == null or _customer.texture == null:
		return
	var w: float = float(_customer.texture.get_width())
	var h: float = float(_customer.texture.get_height())
	_cust_occ.occluder.polygon = PackedVector2Array([Vector2(-w * 0.3, 0.0), Vector2(-w * 0.3, -h * 0.55), Vector2(-w * 0.14, -h * 0.95),
		Vector2(w * 0.14, -h * 0.95), Vector2(w * 0.3, -h * 0.55), Vector2(w * 0.3, 0.0)])


# ---------------------------------------------------------------- drawing

func _vsize() -> Vector2:
	return Vector2(VIEW_SIZE)


func _draw_hall() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var red: bool = _wake_tick >= 0
	var r: Rect2 = DOOR_RECT
	_hall.draw_rect(r, pal[0])
	_hall.draw_rect(r.grow(-5.0), pal[12] if red else pal[1])
	var far: Rect2 = r.grow(-13.0)
	_hall.draw_rect(far, pal[2] if not red else pal[13])
	_hall.draw_rect(Rect2(far.position.x + 5.0, far.position.y + 6.0, far.size.x - 10.0, far.size.y - 6.0), pal[0])
	_hall.draw_rect(Rect2(far.position.x + 5.0, far.end.y - 1.0, far.size.x - 10.0, 1.0), pal[11] if not red else pal[13])  # light under a far door
	_hall.draw_rect(Rect2(r.position.x + 5.0, r.end.y - 9.0, r.size.x - 10.0, 9.0), pal[8])


func _draw_decor() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var vw: float = float(VIEW_SIZE.x)
	var black: Color = pal[0]
	# the clock and its pendulum
	var ctex: Texture2D = _art("clock")
	var ctop := Vector2(CLOCK_POS.x - 12.0, CLOCK_POS.y - 24.0)
	if ctex != null:
		_decor.draw_texture(ctex, ctop)
	else:
		_decor.draw_rect(Rect2(ctop - Vector2.ONE, Vector2(26.0, 50.0)), pal[0])
		_decor.draw_rect(Rect2(ctop, Vector2(24.0, 48.0)), pal[8])
		_decor.draw_rect(Rect2(ctop.x + 4.0, ctop.y + 4.0, 16.0, 14.0), pal[14])
		_decor.draw_rect(Rect2(ctop.x + 4.0, ctop.y + 22.0, 16.0, 22.0), pal[0])
	var pivot := Vector2(CLOCK_POS.x, ctop.y + 22.0)
	var ang: float = sin(_t * PI) * 0.32
	var bob: Vector2 = pivot + Vector2(sin(ang), cos(ang)) * 16.0
	_decor.draw_line(pivot, bob, pal[9], 1.0)
	_decor.draw_rect(Rect2(roundf(bob.x) - 2.0, roundf(bob.y) - 2.0, 4.0, 4.0), pal[10])
	# portraits
	var ptex: Texture2D = _art("portrait")
	for pp: Vector2 in PORTRAIT_POSES:
		var top: Vector2 = pp - Vector2(12.0, 16.0)
		if ptex != null:
			_decor.draw_texture(ptex, top)
		else:
			_decor.draw_rect(Rect2(top - Vector2(2.0, 2.0), Vector2(28.0, 36.0)), pal[8])
			_decor.draw_rect(Rect2(top, Vector2(24.0, 32.0)), pal[0])
			_decor.draw_rect(Rect2(top.x + 7.0, top.y + 6.0, 10.0, 12.0), pal[2])
			_decor.draw_rect(Rect2(top.x + 3.0, top.y + 20.0, 18.0, 12.0), pal[1])
	_draw_cabinet(pal)
	# sconce brackets (the flames are drawn on the glow layer)
	for tc: Vector2 in TORCHES:
		_decor.draw_rect(Rect2(tc.x - 3.0, tc.y - 4.0, 6.0, 14.0), pal[8])
		_decor.draw_rect(Rect2(tc.x - 5.0, tc.y - 6.0, 10.0, 3.0), pal[9])
		_decor.draw_rect(Rect2(tc.x - 1.0, tc.y + 10.0, 2.0, 6.0), pal[0])
	# depth haze: the far wall sits in a cold murk that the shelves and counter stand out from
	var haze: Color = pal[2]
	haze.a = 0.12
	_decor.draw_rect(Rect2(-12.0, -12.0, vw + 24.0, FLOOR_Y + 24.0), haze)
	# deep shadows: ceiling, corners and the floor in front of the counter
	for i: int in range(9):
		black.a = 0.42 * (1.0 - float(i) / 9.0)
		_decor.draw_rect(Rect2(-12.0, float(i) * 8.0, vw + 24.0, 8.0), black)
	for i: int in range(7):
		black.a = 0.45 * (1.0 - float(i) / 7.0)
		_decor.draw_rect(Rect2(float(i) * 5.0, 0.0, 5.0, FLOOR_Y), black)
		_decor.draw_rect(Rect2(vw - float(i + 1) * 5.0, 0.0, 5.0, FLOOR_Y), black)
	for i: int in range(8):
		black.a = 0.55 * (1.0 - float(i) / 8.0)
		_decor.draw_rect(Rect2(-12.0, FLOOR_Y + 1.0 + float(i) * 6.0, vw + 24.0, 6.0), black)


func _draw_outside() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var w: Rect2 = WINDOW_RECT
	var n: float = dread_norm()
	# moon, drifting cloud and a few stars
	_outside.draw_circle(w.position + Vector2(64.0, 30.0), 10.0, pal[15])
	_outside.draw_circle(w.position + Vector2(69.0, 27.0), 9.0, pal[2])
	for s: int in range(5):
		_outside.draw_rect(Rect2(w.position.x + 8.0 + float(s * 17 % 70), w.position.y + 8.0 + float(s * 29 % 40), 1.0, 1.0), pal[14] if int(_t * 1.5 + float(s)) % 3 != 0 else pal[4])
	var cx: float = fposmod(_t * 3.0, w.size.x + 40.0) - 30.0
	_outside.draw_rect(Rect2(w.position.x + cx, w.position.y + 46.0, 28.0, 4.0), pal[3])
	_outside.draw_rect(Rect2(w.position.x + cx + 6.0, w.position.y + 42.0, 16.0, 4.0), pal[3])
	# a moth at the glass
	var mc: Vector2 = w.position + Vector2(30.0, 96.0)
	var mp := Vector2(mc.x + sin(_t * 1.7) * 22.0 + sin(_t * 5.3) * 4.0, mc.y + sin(_t * 2.3) * 14.0 + sin(_t * 7.1) * 3.0)
	var mt: Texture2D = _art("moth")
	if mt != null:
		_outside.draw_texture(mt, mp - Vector2(3.0, 2.0))
	else:
		var flap: int = int(_t * 8.0) % 2
		_outside.draw_rect(Rect2(mp.x - 1.0, mp.y - 1.0, 2.0, 3.0), pal[14])
		_outside.draw_rect(Rect2(mp.x - 4.0, mp.y - 2.0 + float(flap) * 2.0, 3.0, 2.0), pal[4])
		_outside.draw_rect(Rect2(mp.x + 1.0, mp.y - 2.0 + float(flap) * 2.0, 3.0, 2.0), pal[4])
	# 0.7: a shadow passes the window
	if n >= 0.7 and _wake_tick < 0:
		var cyc: float = fposmod(_t, 11.0)
		if cyc < 1.4:
			var k: float = _ease(cyc / 1.4)
			var sx: float = lerpf(w.position.x - 30.0, w.end.x + 10.0, k)
			var sh: Color = pal[0]
			sh.a = 0.85
			_outside.draw_rect(Rect2(sx, w.position.y + 20.0, 22.0, w.size.y - 20.0), sh)
			_outside.draw_circle(Vector2(sx + 11.0, w.position.y + 26.0), 8.0, sh)
	# 0.9: a figure stands motionless outside
	if n >= 0.9:
		var fa: float = _ease((n - 0.9) / 0.1)
		var fc: Color = pal[0]
		fc.a = fa
		var fxp: float = w.position.x + 17.0
		_outside.draw_circle(Vector2(fxp, w.end.y - 92.0), 6.0, fc)
		_outside.draw_rect(Rect2(fxp - 3.0, w.end.y - 88.0, 6.0, 6.0), fc)
		_outside.draw_colored_polygon(PackedVector2Array([Vector2(fxp - 3.0, w.end.y - 84.0), Vector2(fxp + 3.0, w.end.y - 84.0),
			Vector2(fxp + 11.0, w.end.y - 76.0), Vector2(fxp + 9.0, w.end.y), Vector2(fxp - 9.0, w.end.y), Vector2(fxp - 11.0, w.end.y - 76.0)]), fc)


func _draw_near() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var vw: float = float(VIEW_SIZE.x)
	var dark: Color = pal[0]
	dark.a = 0.9
	var mist: Color = pal[1]
	mist.a = 0.5
	var lv: float = clampf(_level, 0.0, 1.0)
	# hanging chains
	for ci: int in range(3):
		var cx: float = [46.0, 596.0, 620.0][ci]
		var len: int = [9, 12, 6][ci]
		for li: int in range(len):
			var sway: float = roundf(sin(_t * 0.8 + float(ci)) * float(li) * 0.25)
			var y: float = -4.0 + float(li) * 6.0
			_near_draw.draw_rect(Rect2(cx + sway - 2.0, y, 4.0, 5.0), dark if li % 2 == 0 else pal[1])
			_near_draw.draw_rect(Rect2(cx + sway - 1.0, y + 1.0, 2.0, 3.0), pal[8] if li % 2 == 0 else pal[0])
	# a dangling bulb on a wire, flickering like it is not sure
	var bx: float = 214.0 + roundf(sin(_t * 0.9) * 2.0)
	_near_draw.draw_rect(Rect2(bx, -4.0, 1.0, 58.0), dark)
	var on: bool = sin(_t * 3.1) + sin(_t * 17.0) * 0.4 > -0.3
	var halo: Color = pal[10]
	halo.a = 0.18 * lv if on else 0.03
	_near_draw.draw_circle(Vector2(bx, 60.0), 13.0, halo)
	_near_draw.draw_rect(Rect2(bx - 3.0, 54.0, 7.0, 3.0), dark)
	_near_draw.draw_rect(Rect2(bx - 3.0, 57.0, 7.0, 6.0), pal[11] if on and lv > 0.2 else pal[2])
	_near_draw.draw_rect(Rect2(bx - 2.0, 63.0, 5.0, 2.0), pal[11] if on and lv > 0.2 else pal[2])
	# the edge of a chandelier, out of focus, in the top right corner
	for k: int in range(4):
		var ax: float = vw - 70.0 + float(k) * 20.0
		_near_draw.draw_rect(Rect2(ax, 0.0, 3.0, 22.0 + float(k % 2) * 10.0), dark)
		_near_draw.draw_rect(Rect2(ax - 2.0, 20.0 + float(k % 2) * 10.0, 7.0, 3.0), mist)
	_near_draw.draw_rect(Rect2(vw - 80.0, 0.0, 80.0, 5.0), dark)
	# cobwebs in the corners
	var web: Color = pal[14]
	web.a = 0.28
	for side: int in range(2):
		var sx: float = 0.0 if side == 0 else vw
		var dir: float = 1.0 if side == 0 else -1.0
		for sp: int in range(5):
			var a: float = float(sp) * 0.3
			_near_draw.draw_line(Vector2(sx, 0.0), Vector2(sx + dir * cos(a) * 64.0, sin(a) * 64.0), web, 1.0)
		for ring: int in range(1, 4):
			var r: float = float(ring) * 17.0
			for sp: int in range(4):
				var a0: float = float(sp) * 0.3
				var a1: float = float(sp + 1) * 0.3
				var mid: float = (a0 + a1) * 0.5
				_near_draw.draw_line(Vector2(sx + dir * cos(a0) * r, sin(a0) * r), Vector2(sx + dir * cos(mid) * (r - 2.0), sin(mid) * (r - 2.0)), web, 1.0)
				_near_draw.draw_line(Vector2(sx + dir * cos(mid) * (r - 2.0), sin(mid) * (r - 2.0)), Vector2(sx + dir * cos(a1) * r, sin(a1) * r), web, 1.0)
	# out-of-focus junk in the near foreground: soft layered silhouettes
	for halo_i: int in range(3):
		var g: float = float(3 - halo_i) * 2.0
		var jc: Color = pal[1] if halo_i < 2 else pal[0]
		jc.a = 0.3 if halo_i < 2 else 0.92
		_near_draw.draw_rect(Rect2(-12.0 - g, 326.0 - g, 88.0 + g * 2.0, 50.0 + g), jc)
		_near_draw.draw_rect(Rect2(14.0 - g, 306.0 - g, 40.0 + g * 2.0, 24.0 + g), jc)
		_near_draw.draw_rect(Rect2(vw - 44.0 - g, 262.0 - g, 9.0 + g * 2.0, 120.0), jc)
		_near_draw.draw_rect(Rect2(vw - 66.0 - g, 252.0 - g, 52.0 + g * 2.0, 16.0 + g), jc)


func _draw_flame(ci: CanvasItem, base: Vector2, frame: int, px: float, dip: int, red: bool) -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var rows: Array = FLAMES[frame % FLAMES.size()] as Array
	var cols: Dictionary = {"o": pal[10], "i": pal[11], "c": pal[15]}
	if red:
		cols = {"o": pal[12], "i": pal[13], "c": pal[11]}
	var nrows: int = rows.size()
	for ri: int in range(dip, nrows):
		var row: String = str(rows[ri])
		for xi: int in range(row.length()):
			var ch: String = row[xi]
			if ch == ".":
				continue
			ci.draw_rect(Rect2(base.x + float(xi - 2) * px - px * 0.5, base.y - float(nrows - ri) * px, px, px), cols[ch] as Color)


func _draw_fx() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var vs: Vector2 = _vsize()
	var n: float = dread_norm()
	var lv: float = _lv()
	var red: bool = _red > 0.3
	var gut: float = clampf((n - 0.3) / 0.3, 0.0, 1.0)
	# candles: wax and a 4-frame pixel flame loop at 8 fps; from Dread 0.3 they gutter
	var i: int = 0
	for c: Vector2 in CANDLES:
		if lv > 0.08:
			_fx.draw_rect(Rect2(c.x - 2.0, c.y - 9.0, 4.0, 9.0), pal[14])
			_fx.draw_rect(Rect2(c.x - 2.0, c.y - 9.0, 4.0, 1.0), pal[15])
			_fx.draw_rect(Rect2(c.x + 1.0, c.y - 8.0, 1.0, 8.0), pal[4])
			var dip: int = int(gut * _ease((sin(_t * (3.1 + float(i) * 0.7) + float(i) * 2.0) - 0.7) / 0.3) * 3.0)
			if _coll_t > 0.0:
				dip = maxi(dip, int(minf(collector_gutter() * 5.0, 1.0) * 3.0))
			_draw_flame(_fx, Vector2(c.x, c.y - 9.0), int(_t * FLAME_FPS + float(i) * 1.7), 1.0, dip, red)
		i += 1
	# wall torches: the same loop at 2x on iron brackets
	i = 0
	for tc: Vector2 in TORCHES:
		if lv > 0.08:
			var tp: Vector2 = tc + _far_off
			var dip2: int = int(gut * _ease((sin(_t * (2.3 + float(i)) + 1.0) - 0.75) / 0.25) * 3.0)
			_draw_flame(_fx, tp + Vector2(0.0, -6.0), int(_t * FLAME_FPS + float(i) * 2.0), 2.0, dip2, red)
		i += 1
	# dust motes drifting through the candlelight and the moon shafts
	if lv > 0.1 and _red < 0.3:
		for m: Dictionary in _motes:
			var ph: float = float(m["ph"])
			var sp: float = float(m["sp"])
			var r: float = float(m["r"])
			var mp: Vector2 = (m["c"] as Vector2) + Vector2(cos(ph + _t * 0.25 * sp) * r, sin(ph * 1.3 + _t * 0.18 * sp) * r * 0.55)
			var a: float = (0.25 + 0.5 * (0.5 + 0.5 * sin(_t * sp * 1.9 + ph))) * lv
			var mc: Color = pal[int(m["col"])]
			mc.a = a
			_fx.draw_rect(Rect2(roundf(mp.x), roundf(mp.y), 1.0, 1.0), mc)
	# 0.5: a pair of eyes in the dark corner (shut while the customer speaks)
	_draw_eyes(pal, n)
	# 0.7: the portraits' eyes follow the customer
	if n >= 0.7 and _wake_tick < 0:
		var follow: float = _cust_x if _cust_state != "none" else STAND_X
		var ga: float = _ease((n - 0.7) / 0.1)
		for pp: Vector2 in PORTRAIT_POSES:
			var dx: float = clampf((follow - pp.x) / 120.0, -1.0, 1.0)
			var gc: Color = pal[11]
			gc.a = ga
			for ex: float in [-4.0, 4.0]:
				_fx.draw_rect(Rect2(roundf(pp.x + _far_off.x + ex + dx * 1.4), pp.y + _far_off.y - 6.0, 2.0, 2.0), gc)
	if _fx_kind != "":
		_draw_tool_fx(pal)
	# fog: from the start a little, breathing at 0.9
	if n > 0.05:
		var breathe: float = 1.0
		if n >= 0.9:
			breathe = 0.65 + 0.35 * sin(_t * 0.55)
		_draw_fog(pal, vs, n, breathe)
	_draw_occult(pal)
	_fx_sys.draw(_fx, pal)
	# the wake beat: red flicker and the tall silhouette behind the counter
	if _flash > 0.0:
		var full: bool = scare_level != 0
		if full:
			var rc2: Color = pal[13]
			rc2.a = 0.55 * _flash
			_fx.draw_rect(Rect2(Vector2.ZERO, vs), rc2)
			_draw_silhouette(pal, 1.0, 1.5)
		else:
			# gentle: one slow swell, never a strobe. A pale cold backlight behind the figure so the black shape
			# reads, a red wash at the edges, and the figure a little larger than life
			var wash: Color = pal[12]
			wash.a = 0.38 * _flash
			_fx.draw_rect(Rect2(Vector2.ZERO, vs), wash)
			var back: Color = pal[4]
			back.a = 0.9 * _flash
			_fx.draw_texture_rect(_bloom_texture(), Rect2(SILHOUETTE_X - 130.0, COUNTER_TOP - 220.0, 260.0, 250.0), false, back)
			var back2: Color = pal[14]
			back2.a = 0.5 * _flash
			_fx.draw_texture_rect(_bloom_texture(), Rect2(SILHOUETTE_X - 60.0, COUNTER_TOP - 170.0, 120.0, 190.0), false, back2)
			_draw_silhouette(pal, 1.0, 1.25)
	if _red > 0.05:
		var rc: Color = pal[12]
		rc.a = 0.3 * clampf(_red, 0.0, 1.0)
		_fx.draw_rect(Rect2(Vector2.ZERO, vs), rc)
	if _bf > 0.01:
		var bc: Color = pal[13]
		bc.a = (0.42 if scare_level != 0 else 0.1) * _bf
		_fx.draw_rect(Rect2(Vector2.ZERO, vs), bc)


func _occ_icon(id: String) -> Texture2D:
	if not _occ_tex.has(id):
		_occ_tex[id] = SpriteKit.spell_icon(id)
	return _occ_tex[id] as Texture2D


## Elliptical ring (a circle seen from above the counter or the floor) as a pixel-snapped polyline.
func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(n + 1):
		var a: float = rot + TAU * float(i) / float(n)
		pts.append(Vector2(roundf(c.x + cos(a) * rx), roundf(c.y + sin(a) * ry)))
	return pts


## Occult effects drawn above the lit world: the Midnight Table lamp, the summoning sigil, the seal's chalk circle,
## the scrying eye and the hex chains. Everything is a few rects or lines, so the cost is tiny.
func _draw_occult(pal: PackedColorArray) -> void:
	if _glam_t > 0.0:  # glamour: a warm gold shimmer washes over every shelf unit
		var gk: float = clampf(_glam_t / GLAMOUR_SECS, 0.0, 1.0)
		var gw: Color = pal[11]
		gw.a = 0.3 * minf(gk * 3.0, 1.0) * (0.7 + 0.3 * sin(_t * 14.0))
		for ux: float in UNIT_XS:
			_fx.draw_texture_rect(_bloom_texture(), Rect2(ux - UNIT_W * 0.5, BOARD_YS[0] - 60.0, UNIT_W, BOARD_YS[2] - BOARD_YS[0] + 76.0), false, gw)
	if _glim_t > 0.0 and _counter_obj != null and _counter_obj.visible:  # found_hint: a pale glint on the object
		var lk: float = clampf(_glim_t / GLIMMER_SECS, 0.0, 1.0)
		var lw: Color = pal[15]
		lw.a = 0.3 * minf(lk * 3.0, 1.0) * (0.6 + 0.4 * sin(_t * 17.0))
		_fx.draw_texture_rect(_bloom_texture(), Rect2(_counter_obj.position.x - 34.0, _counter_obj.position.y - 34.0, 68.0, 68.0), false, lw)
	if _banish_t > 0.0:  # banish: a violet ring leaps out from the shelf and the ghost glyph rises and fades
		var bk: float = 1.0 - _banish_t / BANISH_RING_SECS
		var r1: Color = pal[4]
		r1.a = 1.0 - bk
		_fx.draw_polyline(_ellipse_pts(_banish_at, 6.0 + bk * 38.0, 3.0 + bk * 15.0, 28, 0.0), r1, 2.0)
		var r2: Color = pal[3]
		r2.a = 0.8 * (1.0 - bk)
		_fx.draw_polyline(_ellipse_pts(_banish_at, 3.0 + bk * 24.0, 1.5 + bk * 9.0, 24, 0.0), r2, 1.0)
		_fx.draw_texture_rect(_occ_icon("banish"), Rect2(_banish_at.x - 16.0, _banish_at.y - 16.0 - bk * 22.0, 32.0, 32.0), false, Color(1.0, 1.0, 1.0, 1.0 - bk))
	if _table_k > 0.02:
		var lc: Color = pal[7]
		lc.a = 0.3 * _table_k
		_fx.draw_texture_rect(_bloom_texture(), Rect2(LAMP_POS.x - 90.0, LAMP_POS.y - 40.0, 180.0, 150.0), false, lc)
		var cord: Color = pal[1]
		_fx.draw_line(Vector2(LAMP_POS.x, 0.0), LAMP_POS + Vector2(0.0, -2.0), cord, 1.0)
		_fx.draw_colored_polygon(PackedVector2Array([LAMP_POS + Vector2(-4.0, -2.0), LAMP_POS + Vector2(4.0, -2.0),
			LAMP_POS + Vector2(10.0, 12.0), LAMP_POS + Vector2(-10.0, 12.0)]), pal[5].lerp(pal[6], _table_k))
		_fx.draw_rect(Rect2(LAMP_POS.x - 10.0, LAMP_POS.y + 12.0, 20.0, 1.0), pal[0])
		_fx.draw_rect(Rect2(LAMP_POS.x - 2.0, LAMP_POS.y + 13.0, 4.0, 3.0), pal[7])
		var cone: Color = pal[7]
		cone.a = 0.12 * _table_k
		_fx.draw_colored_polygon(PackedVector2Array([LAMP_POS + Vector2(-8.0, 14.0), LAMP_POS + Vector2(8.0, 14.0),
			Vector2(LAMP_POS.x + 56.0, COUNTER_TOP + 14.0), Vector2(LAMP_POS.x - 56.0, COUNTER_TOP + 14.0)]), cone)
	if _sigil_a > 0.02:
		var pulse: float = 0.75 + 0.25 * sin(_t * 4.0)
		var sc: Color = pal[13]
		sc.a = _sigil_a * (0.85 + 0.15 * sin(_t * 4.0))
		var glow: Color = pal[12]
		glow.a = 0.5 * _sigil_a
		_fx.draw_texture_rect(_bloom_texture(), Rect2(SIGIL_POS.x - 54.0, SIGIL_POS.y - 20.0, 108.0, 40.0), false, glow)
		_fx.draw_polyline(_ellipse_pts(SIGIL_POS, 52.0, 11.0, 40, 0.0), sc, 2.0)
		_fx.draw_polyline(_ellipse_pts(SIGIL_POS, 43.0, 9.0, 36, 0.0), sc, 1.0)
		var star := PackedVector2Array()
		for k: int in range(6):
			var a2: float = -PI * 0.5 + float(k) * TAU * 2.0 / 5.0 + _t * 0.2
			star.append(Vector2(roundf(SIGIL_POS.x + cos(a2) * 41.0), roundf(SIGIL_POS.y + sin(a2) * 8.5)))
		_fx.draw_polyline(star, sc, 1.0)
		var core: Color = pal[11]
		core.a = _sigil_a * pulse
		_fx.draw_rect(Rect2(SIGIL_POS.x - 1.0, SIGIL_POS.y - 1.0, 3.0, 2.0), core)
	if _seal_a > 0.02:
		var cp: float = 0.7 + 0.3 * sin(_t * 2.6)
		var ch: Color = pal[15]
		ch.a = _seal_a * (0.8 + 0.2 * sin(_t * 2.6))
		var hc: Color = pal[14]
		hc.a = 0.5 * _seal_a * cp
		_fx.draw_texture_rect(_bloom_texture(), Rect2(CHALK_POS.x - 52.0, CHALK_POS.y - 16.0, 104.0, 32.0), false, hc)
		_fx.draw_polyline(_ellipse_pts(CHALK_POS, 40.0, 7.0, 40, 0.0), ch, 2.0)
		_fx.draw_polyline(_ellipse_pts(CHALK_POS, 33.0, 5.0, 32, 0.0), ch, 1.0)
		for k2: int in range(8):
			var a3: float = float(k2) * TAU / 8.0
			_fx.draw_rect(Rect2(roundf(CHALK_POS.x + cos(a3) * 36.5) - 1.0, roundf(CHALK_POS.y + sin(a3) * 6.0) - 1.0, 3.0, 3.0), ch)
	if _scry_t > 0.0:
		var k3: float = _scry_t / SCRY_SECS
		var ea: float = clampf(minf(k3 * 4.0, (1.0 - k3) * 5.0), 0.0, 1.0)
		var ep := Vector2(COUNTER_OBJ_X, COUNTER_TOP - 64.0 - (1.0 - k3) * 6.0)
		var eg: Color = pal[7]
		eg.a = 0.5 * ea
		_fx.draw_texture_rect(_bloom_texture(), Rect2(ep.x - 40.0, ep.y - 28.0, 80.0, 56.0), false, eg)
		var ec := Color(1.0, 1.0, 1.0, ea)
		_fx.draw_texture_rect(_occ_icon("scry"), Rect2(ep.x - 24.0, ep.y - 24.0, 48.0, 48.0), false, ec)
		var beam: Color = pal[7]
		beam.a = 0.18 * ea
		_fx.draw_colored_polygon(PackedVector2Array([ep + Vector2(-3.0, 18.0), ep + Vector2(3.0, 18.0),
			Vector2(COUNTER_OBJ_X + 16.0, COUNTER_TOP - 8.0), Vector2(COUNTER_OBJ_X - 16.0, COUNTER_TOP - 8.0)]), beam)
	if _hexed and _customer != null and _cust_state != "none":
		_draw_hex_chains(pal)


func _draw_hex_chains(pal: PackedColorArray) -> void:
	var h: float = float(_customer.texture.get_height()) if _customer.texture != null else 96.0
	var c := Vector2(_customer.position.x, _customer.position.y - h * 0.58)
	var halo: Color = pal[3]
	halo.a = 0.4
	_fx.draw_texture_rect(_bloom_texture(), Rect2(c.x - 44.0, c.y - 40.0, 88.0, 80.0), false, halo)
	for ring: int in range(2):
		var ry: float = 12.0 + float(ring) * 10.0
		var rx: float = 30.0 - float(ring) * 4.0
		var cc := Vector2(c.x, c.y - 10.0 + float(ring) * 22.0)
		for i: int in range(14):
			var a: float = TAU * float(i) / 14.0 + _t * (0.9 - float(ring) * 1.8)
			var p := Vector2(roundf(cc.x + cos(a) * rx), roundf(cc.y + sin(a) * ry))
			var front: bool = sin(a) > 0.0
			var col: Color = pal[4] if front else pal[3]
			if i % 2 == 0:  # a link seen end on (tall) and one side on (wide), each with a bright top edge
				_fx.draw_rect(Rect2(p.x - 2.0, p.y - 3.0, 4.0, 6.0), pal[0])
				_fx.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 2.0, 4.0), col)
				_fx.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 2.0, 1.0), pal[14])
			else:
				_fx.draw_rect(Rect2(p.x - 3.0, p.y - 2.0, 6.0, 4.0), pal[0])
				_fx.draw_rect(Rect2(p.x - 2.0, p.y - 1.0, 4.0, 2.0), col)
				_fx.draw_rect(Rect2(p.x - 2.0, p.y - 1.0, 4.0, 1.0), pal[14])


## Dread fog: four layers of thin wisps (a tileable stretched-noise texture) drifting at different speeds and
## directions, each in a cold palette purple, thicker near the floor. Palette 2-4 only, so it never reads green.
func _draw_fog(pal: PackedColorArray, vs: Vector2, n: float, breathe: float) -> void:
	var wt: Texture2D = _fog_texture()
	var tile_w: float = 420.0
	var layer_cols: Array[int] = [3, 4, 3, 4]
	var layer_y: Array[float] = [168.0, 214.0, 258.0, 296.0]
	var layer_h: Array[float] = [70.0, 84.0, 96.0, 70.0]
	var layer_v: Array[float] = [6.0, -9.0, 13.0, -5.0]
	for j: int in range(4):
		var col: Color = pal[layer_cols[j]]
		col.a = minf((0.34 + 0.08 * float(j)) * (0.5 + 1.2 * n), 0.85) * breathe
		var drift: float = fposmod(_t * layer_v[j] + float(j) * 130.0, tile_w)
		var bob: float = sin(_t * 0.35 + float(j) * 1.9) * 7.0
		var y: float = layer_y[j] + bob
		var x: float = -drift
		while x < vs.x:
			_fx.draw_texture_rect(wt, Rect2(x, y - layer_h[j] * 0.5, tile_w, layer_h[j]), false, col)
			x += tile_w
	var tint: Color = pal[1]
	tint.a = minf(0.22 * n, 0.3) * breathe
	_fx.draw_rect(Rect2(Vector2.ZERO, vs), tint)


## Hash for the wisp noise (no global RNG: the fog has to look the same in every capture).
static func wisp_hash(ix: int, iy: int, oct: int) -> float:
	return fposmod(sin(float(ix) * 127.1 + float(iy) * 311.7 + float(oct) * 74.7) * 43758.5453, 1.0)


static func wisp_noise(px: float, py: float, cells_x: int, oct: int) -> float:
	var ix: int = int(floorf(px))
	var iy: int = int(floorf(py))
	var fx: float = px - float(ix)
	var fy: float = py - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0: int = posmod(ix, cells_x)  # wraps, so the tile repeats seamlessly sideways
	var x1: int = posmod(ix + 1, cells_x)
	var a: float = lerpf(wisp_hash(x0, iy, oct), wisp_hash(x1, iy, oct), fx)
	var b: float = lerpf(wisp_hash(x0, iy + 1, oct), wisp_hash(x1, iy + 1, oct), fx)
	return lerpf(a, b, fy)


## A soft round bloom (white centre fading to nothing), tinted at draw time.
func _bloom_texture() -> Texture2D:
	if _bloom_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.45), Color(1.0, 1.0, 1.0, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 64
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		_bloom_tex = gt
	return _bloom_tex


func _fog_texture() -> Texture2D:
	if _fog_tex == null:
		var w: int = 128
		var h: int = 40
		var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for y: int in range(h):
			var env: float = sin(PI * float(y) / float(h - 1))
			for x: int in range(w):
				var v: float = 0.0
				var amp: float = 0.55
				var f: int = 1
				for o: int in range(3):
					v += amp * wisp_noise(float(x) / float(w) * float(3 * f), float(y) / float(h) * float(2 * f) * 1.0, 3 * f, o)
					amp *= 0.5
					f *= 2
				var a: float = clampf((v - 0.38) * 2.6, 0.0, 1.0) * env
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_fog_tex = ImageTexture.create_from_image(img)
	return _fog_tex


func _draw_eyes(pal: PackedColorArray, _n: float) -> void:
	var o: float = _ease(_eye_open)
	if o <= 0.02:
		return
	if fposmod(_t, 6.3) < 0.14:
		o *= 0.2
	var et: Texture2D = _art("eyes")
	var ep: Vector2 = EYES_POS + _far_off
	var pulse: float = 0.75 + 0.25 * sin(_t * 2.1)
	var halo: Color = pal[12]
	halo.a = 0.7 * o * pulse
	_fx.draw_texture_rect(_bloom_texture(), Rect2(ep.x - 60.0, ep.y - 24.0, 120.0, 48.0), false, halo)  # a faint red bloom around them
	var core: Color = pal[13]
	core.a = 0.3 * o
	_fx.draw_rect(Rect2(ep.x - 30.0, ep.y - 2.0, 60.0, 4.0), core)
	if et != null:
		var ew: float = float(et.get_width()) * EYES_SCALE
		var eh: float = float(et.get_height()) * EYES_SCALE * minf(o * 1.6, 1.0)
		var tint := Color(1.0, 1.0, 1.0, minf(o * 1.5, 1.0))
		_fx.draw_texture_rect(et, Rect2(ep.x - ew * 0.5, ep.y - eh * 0.5, ew, eh), false, tint)
		return
	var h: float = maxf(roundf(o * 8.0), 1.0)
	for sx: float in [-13.0, 13.0]:
		_fx.draw_rect(Rect2(ep.x + sx - 7.0, ep.y - h * 0.5, 14.0, h), pal[12])
		if h >= 3.0:
			_fx.draw_rect(Rect2(ep.x + sx - 5.0, ep.y - h * 0.5 + 1.0, 10.0, maxf(h - 2.0, 1.0)), pal[13])
		if h >= 6.0:
			_fx.draw_rect(Rect2(ep.x + sx - 1.0, ep.y - 2.0, 2.0, 4.0), pal[11])


func _draw_silhouette(pal: PackedColorArray, a: float, zoom: float = 1.0) -> void:
	var st: Texture2D = _art("silhouette")
	if st != null:
		var w: float = float(st.get_width())
		var h: float = float(st.get_height())
		_fx.draw_texture_rect_region(st, Rect2(SILHOUETTE_X - w * 0.5 * zoom, COUNTER_TOP - (h - 14.0) * zoom, w * zoom, (h - 14.0) * zoom),
			Rect2(0.0, 0.0, w, h - 14.0), Color(1.0, 1.0, 1.0, a))
		return
	var c: Color = pal[0]
	c.a = a
	var top: float = COUNTER_TOP - 104.0
	var x: float = SILHOUETTE_X
	_fx.draw_circle(Vector2(x, top + 8.0), 8.0, c)
	_fx.draw_colored_polygon(PackedVector2Array([Vector2(x - 4.0, top + 14.0), Vector2(x + 4.0, top + 14.0), Vector2(x + 22.0, top + 24.0),
		Vector2(x + 20.0, top + 110.0), Vector2(x - 20.0, top + 110.0), Vector2(x - 22.0, top + 24.0)]), c)
	_fx.draw_rect(Rect2(x - 24.0, top + 24.0, 3.0, 70.0), c)  # long thin arms
	_fx.draw_rect(Rect2(x + 21.0, top + 24.0, 3.0, 70.0), c)
	var eye: Color = pal[15]
	eye.a = a
	_fx.draw_rect(Rect2(x - 4.0, top + 7.0, 2.0, 1.0), eye)
	_fx.draw_rect(Rect2(x + 2.0, top + 7.0, 2.0, 1.0), eye)


func _draw_tool_fx(pal: PackedColorArray) -> void:
	var k: float = clampf(_fx_t / FX_SECS, 0.0, 1.0)
	var fade: float = 1.0 - maxf(k - 0.7, 0.0) / 0.3
	var oc := Vector2(COUNTER_OBJ_X, COUNTER_TOP - 18.0)
	if _counter_obj.visible:
		oc = _counter_obj.position
	match _fx_kind:
		"uv":
			var glow: Color = pal[3]
			glow.a = 0.55 * fade
			var lamp := Vector2(_tool_pos.x + 4.0, _tool_pos.y - 4.0)
			_fx.draw_colored_polygon(PackedVector2Array([lamp, oc + Vector2(-30.0, 18.0), oc + Vector2(30.0, 18.0)]),
				Color(pal[3].r, pal[3].g, pal[3].b, 0.3 * fade))
			_fx.draw_circle(oc, 28.0, glow)
			var inner: Color = pal[4]
			inner.a = 0.6 * fade
			_fx.draw_circle(oc, 16.0, inner)
			for m: int in range(7):
				var a: float = float(m) * 0.9 + 0.4
				var p: Vector2 = oc + Vector2(cos(a) * (7.0 + float(m % 3) * 7.0), sin(a) * (6.0 + float(m % 2) * 7.0))
				var mk: Color = pal[15]
				mk.a = clampf(k * 3.0 - float(m) * 0.2, 0.0, 1.0) * fade
				_fx.draw_rect(Rect2(p.x - 1.0, p.y - 3.0, 2.0, 6.0), mk)
				_fx.draw_rect(Rect2(p.x - 3.0, p.y - 1.0, 6.0, 2.0), mk)
		"scale":
			var ang: float = sin(_fx_t * 14.0) * 0.3 * (1.0 - _ease(k))
			var base := Vector2(oc.x, COUNTER_TOP - 44.0)
			var dx: Vector2 = Vector2(cos(ang), sin(ang)) * 26.0
			_fx.draw_line(base - dx, base + dx, pal[14], 2.0)
			_fx.draw_line(base, Vector2(base.x, COUNTER_TOP - 28.0), pal[14], 2.0)
			_fx.draw_circle(base - dx + Vector2(0.0, 3.0), 3.0, pal[11])
			_fx.draw_circle(base + dx + Vector2(0.0, 3.0), 3.0, pal[11])
		"pendulum":
			var anchor := Vector2(oc.x, COUNTER_TOP - 74.0)
			var plen: float = 40.0
			var verdict: bool = _fx_tell != "" and k > 0.45
			var bob: Vector2
			if verdict and _fx_tell == "cursed":  # a cursed thing drags it round in a tight, hungry circle
				bob = anchor + Vector2(cos(_fx_t * 8.0) * 13.0, plen + sin(_fx_t * 8.0) * 5.0)
			else:  # a clean one only sways, then hangs still
				var amp: float = 0.55 * (1.0 - (_ease((k - 0.45) / 0.4) if verdict else 0.0))
				bob = anchor + Vector2(sin(sin(_fx_t * 5.0) * amp) * plen, cos(sin(_fx_t * 5.0) * amp) * plen)
			var chain: Color = pal[14]
			chain.a = fade
			_fx.draw_line(anchor, bob, chain, 1.0)
			var glow: Color = pal[11]
			if verdict:
				glow = pal[13] if _fx_tell == "cursed" else pal[7]
			glow.a = 0.45 * fade
			_fx.draw_texture_rect(_bloom_texture(), Rect2(bob.x - 20.0, bob.y - 20.0, 40.0, 40.0), false, glow)
			var crystal: Color = pal[4]
			crystal.a = fade
			_fx.draw_colored_polygon(PackedVector2Array([bob + Vector2(0.0, -6.0), bob + Vector2(4.0, 0.0), bob + Vector2(0.0, 7.0), bob + Vector2(-4.0, 0.0)]), crystal)
			var hi: Color = pal[15]
			hi.a = fade
			_fx.draw_rect(Rect2(bob.x - 2.0, bob.y - 2.0, 1.0, 2.0), hi)
		"listen":
			for r: int in range(4):
				var rk: float = fposmod(_fx_t * 1.6 + float(r) * 0.25, 1.0)
				var rc: Color = pal[15]
				rc.a = (1.0 - rk) * fade
				_fx.draw_arc(oc, 9.0 + rk * 40.0, 0.0, TAU, 32, rc, 1.0)
		"touch":
			for f: int in range(14):
				var a2: float = float(f) * 0.9
				var rr: float = (7.0 + float((f * 7) % 13) + k * 9.0)
				var p2: Vector2 = oc + Vector2(cos(a2) * rr, sin(a2) * rr * 0.8)
				var fc: Color = pal[15] if f % 2 == 0 else pal[14]
				fc.a = clampf(k * 4.0 - float(f) * 0.1, 0.0, 1.0) * fade
				_fx.draw_rect(Rect2(p2.x - 1.0, p2.y - 1.0, 3.0, 3.0), fc)
				_fx.draw_rect(Rect2(p2.x, p2.y - 3.0, 1.0, 7.0), fc)
