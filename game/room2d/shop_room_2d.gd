class_name ShopRoom2D
extends Node
## The 2D pawnshop: a side-on pixel-art room drawn into a 480x270 SubViewport (Godot Physics 2D, 60 Hz) and shown
## full screen through the 16-colour palette + Bayer dither shader. Built entirely in code. Contract:
## docs/room2d_brief.md. Same API as the old 3D ShopRoom:
##   setup(run)        fill the shelves with one prop per held item
##   apply_events(ev)  react to RunState events
##   set_dread(v)      candle flicker and green fog grow with Dread
##   wake(seed)        deterministic chaos for WAKE_SECS (physics-tick driven, so replays look the same)
## Pixels, Y down. Floor at y=230, counter top at y=170, door at the left edge, shelves wall-mounted at the back.

signal wake_finished

const VIEW_SIZE := Vector2i(480, 270)
const WAKE_SECS: float = 4.0
const TICKS_PER_SEC: int = 60
const FLOOR_Y: float = 230.0
const COUNTER_TOP: float = 170.0
const COUNTER_X0: float = 56.0
const DOOR_RECT := Rect2(4.0, 158.0, 32.0, 72.0)
const STAND_X: float = 438.0
const STAND_Y: float = 174.0  # the whole hood and shoulders show above the counter
const WINDOW_RECT := Rect2(402.0, 70.0, 72.0, 100.0)
const DOOR_X: float = 22.0
const COUNTER_OBJ_X: float = 376.0
const TOOL_POS := Vector2(326.0, 158.0)
const CARD_POS := Vector2(284.0, 150.0)
const UNIT_XS: Array[float] = [104.0, 224.0, 344.0]
const UNIT_W: float = 104.0
const UNIT_TOP: float = 34.0
const UNIT_BOTTOM: float = 150.0
const BOARD_YS: Array[float] = [62.0, 102.0, 142.0]
const SLOTS_PER_BOARD: int = 3
const OVERFLOW_X: float = 92.0
const FX_SECS: float = 1.0
const PROP_ZOOM: float = 2.0  ## tool props and the tarot card are drawn at 2x so they read at 480x270
const CARD_FLIP_SECS: float = 0.9
const BUBBLE_SECS: float = 2.0
const BUBBLE_W: float = 132.0
const WALK_SPEED: float = 140.0
const LIGHT_RISE_PER_SEC: float = 0.6
const LIGHT_FALL_PER_SEC: float = 3.0
const RED_FADE_PER_SEC: float = 0.35
const DOOR_SPEED: float = 5.0
const SETTLE_EASY_TICKS: int = 90
const SETTLE_ALL_TICKS: int = 180
const SETTLE_SPEED: float = 30.0
const PROP_MASS: float = 1.0
const UNIT_MASS: float = 30.0
const LAYER_WORLD: int = 1
const LAYER_COUNTER: int = 2
const LAYER_PROP: int = 4
const LAYER_UNIT: int = 8
const CALM_TONE := Color(1.0, 0.93, 1.0)
const NIGHT_TONE := Color(0.22, 0.16, 0.34)
const RED_TONE := Color(1.0, 0.2, 0.18)
const AMBER_LIGHT := Color(1.0, 0.66, 0.3)
const RED_LIGHT := Color(1.0, 0.16, 0.12)
const UV_COLOR := Color(0.62, 0.30, 1.0)
const CANDLES: Array[Vector2] = [Vector2(70.0, 170.0), Vector2(404.0, 170.0), Vector2(224.0, 34.0)]

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
var _lights: Array[PointLight2D] = []
var _door_sprite: Sprite2D
var _door_gap: ColorRect
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
var _bubble: Control
var _bubble_label: Label
var _bubble_t: float = 0.0
var _counter_obj: Sprite2D
var _counter_cat: String = ""
var _counter_item: Dictionary = {}  ## {id, category} of the object on the counter
var _tool_sprite: Sprite2D
var _fx_kind: String = ""
var _fx_t: float = 0.0
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
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = RoomPalette.make_shader()
	_screen.material = _shader_mat
	_layer.add_child(_screen)
	_apply_dither()


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
		_set_customer_look(tid)
		_line = ""
		_cust_start_enter(oname, cat)
		_cust_state = "here"
		_cust_x = STAND_X
		_show_counter_object()
		_place_customer()


func set_dread(v: float) -> void:
	dread = maxf(v, 0.0)


## 0..1.5, Dread as a fraction of the wake threshold.
func dread_norm() -> float:
	return clampf(dread / maxf(Tuning.shared().wake_threshold, 0.1), 0.0, 1.5)


func apply_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match str(e.get("e", "")):
			"night_start":
				_level_target = 1.0
				_hide_card()
			"customer":
				_hide_card()
				var oname: String = ""
				var cat: String = ""
				if str(e.get("kind", "")) == RunState.SELLER:
					oname = str(e.get("name", ""))
					cat = _category_of_name(oname)
				var tid: String = str(e.get("tid", ""))
				_set_customer_look(tid)
				_line = str(e.get("line", ""))
				if _line == "":
					_line = str(_look_row(tid).get("line", ""))
				_cust_start_enter(oname, cat)
			"passed", "left":
				_cust_start_leave()
			"bought":
				_on_bought(e)
				_cust_start_leave()
			"sold":
				_on_sold(e)
				_cust_start_leave()
			"inspected":
				_start_fx(str(e.get("tool", "")))
			"wager":
				_start_card(str(e.get("card", "")))
			"wake":
				_on_wake_event(e)
			"night_end":
				_cust_start_leave()
				_level = minf(_level, 0.2)
				_level_target = 0.2
			"run_lost":
				_cust_start_leave()
				_level = minf(_level, 0.25)
				_level_target = 0.06
			"run_won":
				_cust_start_leave()
				_level_target = 1.35
			_:
				pass


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
	var bodies: Array[RigidBody2D] = []
	for uid: Variant in _props:
		bodies.append((_props[uid] as Dictionary)["body"] as RigidBody2D)
	if _doomed != null:
		bodies.append(_doomed)
	for body: RigidBody2D in bodies:
		body.freeze = false
		var delay: float = _wake_rng.randf_range(0.2, 2.4)
		var vx: float = _wake_rng.randf_range(70.0, 240.0) * (1.0 if _wake_rng.randf() < 0.5 else -1.0)
		var vy: float = _wake_rng.randf_range(180.0, 380.0)
		var spin: float = _wake_rng.randf_range(-9.0, 9.0)
		var skip: float = _wake_rng.randf()
		if skip < 0.1 and body != _doomed:
			continue
		_plan_add(int(delay * TICKS_PER_SEC), "shove", body, Vector2(vx, -vy) * PROP_MASS, spin)
	var pick: int = _wake_rng.randi_range(0, maxi(_units.size() - 1, 0))
	_plan_add(int(1.35 * TICKS_PER_SEC), "topple", null, Vector2(float(pick), 0.0), 0.0)
	_plan_add(int(0.9 * TICKS_PER_SEC), "slam", null, Vector2.ZERO, 0.0)
	if _doomed != null:
		var shards: Array = []
		for i: int in range(10):
			shards.append({"v": Vector2(_wake_rng.randf_range(-140.0, 140.0), -_wake_rng.randf_range(80.0, 260.0)),
				"c": _wake_rng.randi_range(0, 3)})
		_plan_add(int(1.8 * TICKS_PER_SEC), "shatter", _doomed, Vector2.ZERO, 0.0, shards)
	_plan_add(int(WAKE_SECS * TICKS_PER_SEC), "end", null, Vector2.ZERO, 0.0)
	_wake_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["t"]) < int(b["t"]) or (int(a["t"]) == int(b["t"]) and int(a["n"]) < int(b["n"])))
	_door_target = 1.0
	_door_fast = true
	_shake = 4.0


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


func bubble_text() -> String:
	return _bubble_label.text if _bubble.visible else ""


func has_card() -> bool:
	return _card != null and _card.visible


func fx_kind() -> String:
	return _fx_kind


func light_level() -> float:
	return _level


func viewport() -> SubViewport:
	return _vp


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
		_bubble_t = 0.0
		_show_bubble()
	elif _cust_state == "leave":
		_finish_leave()
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
	_doomed = null
	_wake_tick = -1
	_settle_tick = -1
	_wake_plan.clear()
	_shake = 0.0
	_red = 0.0
	_level = 1.0
	_level_target = 1.0
	_fx_kind = ""
	_card_t = -1.0
	_cust_state = "none"
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
	_build_backdrop()
	_build_bounds()
	_build_units()
	_build_counter()
	_build_customer()
	_build_overlays()
	_build_lights()
	_apply_ambient()


func _tex(kind: String) -> Texture2D:
	if not _tex_cache.has(kind):
		_tex_cache[kind] = SpriteKit.tile_texture(kind)
	return _tex_cache[kind] as Texture2D


func _tile(kind: String, rect: Rect2, z: int, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(kind)
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


func _build_backdrop() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	_tile("wall", Rect2(0.0, 0.0, 480.0, FLOOR_Y), -10, _world)
	_tile("floor", Rect2(0.0, FLOOR_Y, 480.0, 40.0), -10, _world)
	_rect(Rect2(0.0, FLOOR_Y, 480.0, 1.0), pal[0], -9, _world)
	# moonlit window behind the customer's spot, so a dark hood reads against it
	var w: Rect2 = WINDOW_RECT
	_rect(Rect2(w.position - Vector2(2.0, 2.0), w.size + Vector2(4.0, 2.0)), pal[0], -8, _world)
	_rect(w, pal[4], -7, _world)
	_rect(Rect2(w.position.x, w.position.y + 50.0, w.size.x, 50.0), pal[3], -7, _world)
	_rect(Rect2(w.position.x + w.size.x * 0.5 - 1.0, w.position.y, 2.0, w.size.y), pal[0], -6, _world)
	_rect(Rect2(w.position.x, w.position.y + 40.0, w.size.x, 2.0), pal[0], -6, _world)
	# door: dark doorway with a pale gap, and the door leaf hinged on its left edge
	_rect(Rect2(DOOR_RECT.position - Vector2(2.0, 2.0), DOOR_RECT.size + Vector2(4.0, 2.0)), pal[0], -8, _world)
	_door_gap = _rect(DOOR_RECT, pal[2], -7, _world)
	_door_sprite = _tile("door", DOOR_RECT, -6, _world)


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
	_static_box(Rect2(-40.0, FLOOR_Y, 560.0, 40.0), LAYER_WORLD)
	_static_box(Rect2(-40.0, -60.0, 560.0, 60.0), LAYER_WORLD)
	_static_box(Rect2(-40.0, -60.0, 40.0, 400.0), LAYER_WORLD)
	_static_box(Rect2(480.0, -60.0, 40.0, 400.0), LAYER_WORLD)


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
			_add_box_shape(u, Rect2(-UNIT_W * 0.5, ly, UNIT_W, 5.0))
			for si: int in range(SLOTS_PER_BOARD):
				_slots.append({"pos": Vector2(UNIT_XS[ui] - UNIT_W * 0.5 + 6.0 + 16.0 + 34.0 * float(si), by), "unit": ui})
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
	var rect := Rect2(COUNTER_X0, COUNTER_TOP, 480.0 - COUNTER_X0, FLOOR_Y - COUNTER_TOP + 40.0)
	_static_box(rect, LAYER_COUNTER)
	_tile("counter", Rect2(COUNTER_X0, COUNTER_TOP, 480.0 - COUNTER_X0, 70.0), 4, _world)
	_rect(Rect2(COUNTER_X0, COUNTER_TOP, 480.0 - COUNTER_X0, 2.0), pal[0], 5, _world)
	_rect(Rect2(COUNTER_X0, COUNTER_TOP + 2.0, 480.0 - COUNTER_X0, 3.0), pal[9], 5, _world)
	_rect(Rect2(COUNTER_X0 - 1.0, COUNTER_TOP, 1.0, 60.0), pal[0], 5, _world)


func _build_customer() -> void:
	_customer = Sprite2D.new()
	_customer.centered = false
	_customer.z_index = 3
	_customer.visible = false
	_world.add_child(_customer)
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
	_set_customer_texture({})


func _build_overlays() -> void:
	_fx = Node2D.new()
	_fx.z_index = 8
	_fx.draw.connect(_draw_fx)
	_world.add_child(_fx)
	var pal: PackedColorArray = RoomPalette.colors()
	_bubble = Control.new()
	_bubble.z_index = 20
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.name = "Back"
	back.color = pal[0]
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(back)
	var face := ColorRect.new()
	face.name = "Face"
	face.color = pal[15]
	face.position = Vector2(1.0, 1.0)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(face)
	_bubble_label = Label.new()
	_bubble_label.position = Vector2(4.0, 1.0)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.add_theme_font_size_override("font_size", 8)
	_bubble_label.add_theme_color_override("font_color", pal[0])
	_bubble_label.add_theme_constant_override("line_spacing", -2)
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_bubble_label)
	_world.add_child(_bubble)


func _build_lights() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.BLACK)
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
		l.texture_scale = 2.1
		l.position = c + Vector2(0.0, -8.0)
		l.color = AMBER_LIGHT
		l.energy = 1.0
		l.z_index = 0
		_world.add_child(l)
		_lights.append(l)


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
	return Vector2(OVERFLOW_X + float(overflow_i % 5) * 15.0, COUNTER_TOP - float(overflow_i / 5) * 18.0)


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
	sp.texture = tex
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
		var p: Vector2 = (s["from"] as Vector2).lerp(s["to"] as Vector2, t)
		p.y -= sin(t * PI) * 24.0
		body.position = p
		if t >= 1.0:
			body.position = s["to"] as Vector2
			_slides.remove_at(i)


# ---------------------------------------------------------------- customer and counter object

func _set_customer_texture(look: Dictionary) -> void:
	var tex: ImageTexture = SpriteKit.customer_texture(look)
	_customer.texture = tex
	_customer.offset = Vector2(-float(tex.get_width()) * 0.5, -float(tex.get_height()))


## Dresses the figure as customer type `tid` (unchanged if same type).
func _set_customer_look(tid: String) -> void:
	if tid == _look_id or _customer == null:
		return
	_look_id = tid
	_set_customer_texture(_look_row(tid))


func _cust_start_enter(oname: String, category: String) -> void:
	if _cust_state == "leave":
		_finish_leave()
	_hide_counter_object()
	_counter_cat = category
	_counter_item = {}
	if oname != "":
		_counter_item = {"id": _id_of_name(oname), "category": category}
	_cust_state = "enter"
	_cust_x = DOOR_X
	_walk_t = 0.0
	_bubble_t = 0.0
	_bubble.visible = false
	_door_target = 1.0
	_door_fast = false
	_customer.visible = true
	_place_customer()


func _cust_start_leave() -> void:
	if _cust_state == "none":
		return
	_cust_state = "leave"
	_bubble.visible = false
	_bubble_t = 0.0
	_door_target = 1.0
	_door_fast = false


func _finish_leave() -> void:
	_cust_state = "none"
	_customer.visible = false
	_bubble.visible = false
	_hide_counter_object()
	_door_target = 0.0


func _place_customer() -> void:
	var bob: float = 0.0
	if _cust_state == "enter" or _cust_state == "leave":
		bob = absf(sin(_walk_t * 11.0)) * 3.0
	_customer.position = Vector2(_cust_x, STAND_Y - bob)
	_customer.flip_h = _cust_state == "leave"


func _show_counter_object() -> void:
	if _counter_item.is_empty():
		_counter_obj.visible = false
		return
	var tex: ImageTexture = SpriteKit.object_texture(str(_counter_item["id"]), str(_counter_item["category"]))
	_counter_obj.texture = tex
	_counter_obj.position = Vector2(COUNTER_OBJ_X, COUNTER_TOP - float(tex.get_height()) * 0.5)
	_counter_obj.rotation = 0.0
	_counter_obj.visible = true


func _hide_counter_object() -> void:
	_counter_obj.visible = false


func _show_bubble() -> void:
	if _line == "" or _cust_state != "here":
		return
	_bubble_label.text = _line
	_bubble_label.size = Vector2(BUBBLE_W - 8.0, 10.0)
	var chars_per_line: float = (BUBBLE_W - 8.0) / 4.2
	var lines: int = int(ceilf(float(_line.length()) / chars_per_line)) + (1 if _line.length() > 0 else 0)
	lines = clampi(lines, 1, 5)
	var h: float = float(lines) * 8.0 + 4.0
	_bubble_label.size = Vector2(BUBBLE_W - 8.0, h)
	_bubble.size = Vector2(BUBBLE_W, h)
	(_bubble.get_node("Back") as ColorRect).size = Vector2(BUBBLE_W, h)
	(_bubble.get_node("Face") as ColorRect).size = Vector2(BUBBLE_W - 2.0, h - 2.0)
	var top: float = STAND_Y - float(customer_height()) - h - 6.0
	_bubble.position = Vector2(clampf(_cust_x - BUBBLE_W * 0.5, 6.0, 474.0 - BUBBLE_W), maxf(top, 4.0))
	_bubble.visible = true


# ---------------------------------------------------------------- tool effects and card

func _start_fx(tool: String) -> void:
	if not Catalog.TOOLS.has(tool):
		return
	_fx_kind = tool
	_fx_t = 0.0
	_tool_sprite.texture = SpriteKit.tool_texture(tool)
	_tool_sprite.position = TOOL_POS
	_tool_sprite.scale = Vector2.ONE * PROP_ZOOM
	_tool_sprite.visible = true


func _hide_fx() -> void:
	_fx_kind = ""
	_tool_sprite.visible = false
	_counter_obj.rotation = 0.0


func _start_card(card: String) -> void:
	_card_name = card
	_card_t = 0.0
	_card.texture = SpriteKit.card_texture(card, false)
	_card.position = CARD_POS
	_card.scale = Vector2.ONE * PROP_ZOOM
	_card.visible = true


func _hide_card() -> void:
	_card_t = -1.0
	_card.visible = false


func _update_card(delta: float) -> void:
	if _card_t < 0.0:
		return
	_card_t += delta
	var k: float = clampf(_card_t / CARD_FLIP_SECS, 0.0, 1.0)
	_card.texture = SpriteKit.card_texture(_card_name, k >= 0.5)
	_card.scale = Vector2(absf(cos(k * PI)), 1.0) * PROP_ZOOM
	_card.position = CARD_POS + Vector2(0.0, -sin(k * PI) * 12.0)


func _update_fx(delta: float) -> void:
	if _fx_kind == "":
		return
	_fx_t += delta
	var k: float = clampf(_fx_t / FX_SECS, 0.0, 1.0)
	if _fx_kind == "scale" and _counter_obj.visible:
		_counter_obj.rotation = sin(_fx_t * 14.0) * 0.22 * (1.0 - k)
	_tool_sprite.position = TOOL_POS + Vector2(0.0, sin(_fx_t * 6.0) * 1.5)
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
	_apply_ambient()
	_fx.queue_redraw()


func _update_customer(delta: float) -> void:
	match _cust_state:
		"enter":
			_walk_t += delta
			_cust_x = minf(_cust_x + WALK_SPEED * delta, STAND_X)
			if _cust_x >= STAND_X:
				_cust_state = "here"
				_bubble_t = 0.0
				_show_counter_object()
				_show_bubble()
				_door_target = 0.0
			_place_customer()
		"leave":
			_walk_t += delta
			_cust_x -= WALK_SPEED * delta
			if _cust_x <= DOOR_X:
				_finish_leave()
			else:
				_place_customer()
		"here":
			if _bubble.visible:
				_bubble_t += delta
				if _bubble_t >= BUBBLE_SECS:
					_bubble.visible = false
	if _cust_state == "enter" and _cust_x > 60.0:
		_door_target = 0.0


func _update_door(delta: float) -> void:
	var rate: float = DOOR_SPEED * (4.0 if _door_fast else 1.0)
	_door_open = move_toward(_door_open, _door_target, rate * delta)
	_door_sprite.scale.x = lerpf(1.0, 0.12, _door_open)
	_door_gap.color = RoomPalette.colors()[2 if _wake_tick < 0 else 12]


func _update_light_level(delta: float) -> void:
	if _level < _level_target:
		_level = minf(_level + LIGHT_RISE_PER_SEC * delta, _level_target)
	elif _level > _level_target:
		_level = maxf(_level - LIGHT_FALL_PER_SEC * delta, _level_target)
	_red = maxf(_red - RED_FADE_PER_SEC * delta, 0.0)


func _apply_ambient() -> void:
	var lv: float = clampf(_level, 0.0, 1.0)
	var tone: Color = NIGHT_TONE.lerp(CALM_TONE, lv)
	if _level > 1.0:
		tone = CALM_TONE * (1.0 + (_level - 1.0) * 0.6)
		tone.a = 1.0
	tone = tone.lerp(RED_TONE * 0.9, clampf(_red, 0.0, 1.0) * 0.95)
	tone.a = 1.0
	_modulate.color = tone
	var n: float = dread_norm()
	var flick: float = 1.0
	var i: int = 0
	for l: PointLight2D in _lights:
		flick = 1.0 + (sin(_t * (9.0 + float(i) * 2.3) + float(i)) * 0.5 + sin(_t * (23.0 + float(i) * 5.1)) * 0.5) * (0.06 + 0.22 * n)
		if n > 1.0 and sin(_t * (31.0 + float(i))) > 0.9:
			flick *= 0.3
		l.color = AMBER_LIGHT.lerp(RED_LIGHT, clampf(_red, 0.0, 1.0))
		l.energy = (0.35 + 0.65 * lv) * flick * (1.0 + 1.6 * _red)
		i += 1


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
				var body: RigidBody2D = step["body"] as RigidBody2D
				if is_instance_valid(body):
					body.collision_mask = LAYER_WORLD | LAYER_COUNTER | LAYER_PROP  # the poltergeist pulls it through the boards
					body.sleeping = false
					body.apply_central_impulse(step["v"] as Vector2)
					body.angular_velocity = float(step["w"])
					_shake = maxf(_shake, 1.5)
			"topple":
				_topple(int((step["v"] as Vector2).x))
			"slam":
				_door_target = 0.0
				_shake = maxf(_shake, 5.0)
			"shatter":
				_shatter(step["body"] as RigidBody2D, step["shards"] as Array)
			"end":
				_end_wake()
				return
	_wake_tick += 1
	var t: float = float(_wake_tick) / float(TICKS_PER_SEC)
	_level = 0.05
	if t < 0.35:
		_red = 0.0
	else:
		_red = clampf((t - 0.35) * 3.0, 0.0, 1.0) * (0.8 + 0.2 * sin(t * 11.0))
	_shake = maxf(_shake, 1.2)


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
	for b: RigidBody2D in all_bodies():
		b.linear_damp = maxf(b.linear_damp, 1.5)
		b.angular_damp = maxf(b.angular_damp, 3.0)
	wake_finished.emit()


# ---------------------------------------------------------------- drawing (candles, tool effects, fog)

func _draw_fx() -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var n: float = dread_norm()
	# candles
	var i: int = 0
	for c: Vector2 in CANDLES:
		_fx.draw_rect(Rect2(c.x - 2.0, c.y - 9.0, 4.0, 9.0), pal[14])
		_fx.draw_rect(Rect2(c.x - 2.0, c.y - 9.0, 4.0, 1.0), pal[15])
		var fl: float = 3.0 + sin(_t * (13.0 + float(i) * 3.0)) * (1.0 + n)
		var red: bool = _red > 0.3
		_fx.draw_rect(Rect2(c.x - 1.0, c.y - 10.0 - fl, 2.0, fl), pal[13] if red else pal[11])
		_fx.draw_rect(Rect2(c.x - 1.0, c.y - 11.0, 2.0, 2.0), pal[12] if red else pal[10])
		i += 1
	# tool effects over the counter object
	if _fx_kind != "":
		_draw_tool_fx(pal)
	# fog
	if n > 0.05:
		for j: int in range(7):
			var fx: float = fmod(float(j) * 83.0 + _t * (5.0 + float(j) * 2.0), 560.0) - 40.0
			var fy: float = 150.0 + sin(_t * 0.7 + float(j) * 1.7) * 14.0 - float(j % 3) * 22.0
			var col: Color = pal[6]
			col.a = minf(0.32 * n, 0.5)
			_fx.draw_circle(Vector2(fx, fy), 26.0 + float(j % 3) * 8.0, col)
		var tint: Color = pal[5]
		tint.a = minf(0.26 * n, 0.36)
		_fx.draw_rect(Rect2(0.0, 0.0, 480.0, 270.0), tint)
	# red strobe over everything during the wake
	if _red > 0.05:
		var rc: Color = pal[12]
		rc.a = 0.3 * clampf(_red, 0.0, 1.0)
		_fx.draw_rect(Rect2(0.0, 0.0, 480.0, 270.0), rc)


func _draw_tool_fx(pal: PackedColorArray) -> void:
	var k: float = clampf(_fx_t / FX_SECS, 0.0, 1.0)
	var fade: float = 1.0 - maxf(k - 0.7, 0.0) / 0.3
	var oc := Vector2(COUNTER_OBJ_X, COUNTER_TOP - 14.0)
	if _counter_obj.visible:
		oc = _counter_obj.position
	match _fx_kind:
		"uv":
			var glow: Color = pal[3]
			glow.a = 0.55 * fade
			var lamp := Vector2(TOOL_POS.x + 4.0, TOOL_POS.y - 4.0)
			_fx.draw_colored_polygon(PackedVector2Array([lamp, oc + Vector2(-26.0, 14.0), oc + Vector2(26.0, 14.0)]),
				Color(pal[3].r, pal[3].g, pal[3].b, 0.3 * fade))
			_fx.draw_circle(oc, 24.0, glow)
			var inner: Color = pal[4]
			inner.a = 0.6 * fade
			_fx.draw_circle(oc, 14.0, inner)
			for m: int in range(7):
				var a: float = float(m) * 0.9 + 0.4
				var p: Vector2 = oc + Vector2(cos(a) * (6.0 + float(m % 3) * 6.0), sin(a) * (5.0 + float(m % 2) * 6.0))
				var mk: Color = pal[15]
				mk.a = clampf(k * 3.0 - float(m) * 0.2, 0.0, 1.0) * fade
				_fx.draw_rect(Rect2(p.x - 1.0, p.y - 3.0, 2.0, 6.0), mk)
				_fx.draw_rect(Rect2(p.x - 3.0, p.y - 1.0, 6.0, 2.0), mk)
		"scale":
			var ang: float = sin(_fx_t * 14.0) * 0.3 * (1.0 - k)
			var base := Vector2(oc.x, COUNTER_TOP - 34.0)
			var dx: Vector2 = Vector2(cos(ang), sin(ang)) * 22.0
			_fx.draw_line(base - dx, base + dx, pal[14], 2.0)
			_fx.draw_line(base, Vector2(base.x, COUNTER_TOP - 22.0), pal[14], 2.0)
			_fx.draw_circle(base - dx + Vector2(0.0, 3.0), 3.0, pal[11])
			_fx.draw_circle(base + dx + Vector2(0.0, 3.0), 3.0, pal[11])
		"listen":
			for r: int in range(4):
				var rk: float = fmod(_fx_t * 1.6 + float(r) * 0.25, 1.0)
				var rc: Color = pal[15]
				rc.a = (1.0 - rk) * fade
				_fx.draw_arc(oc, 8.0 + rk * 34.0, 0.0, TAU, 32, rc, 1.0)
		"touch":
			for f: int in range(14):
				var a2: float = float(f) * 0.9
				var rr: float = (6.0 + float((f * 7) % 13) + k * 8.0)
				var p2: Vector2 = oc + Vector2(cos(a2) * rr, sin(a2) * rr * 0.8)
				var fc: Color = pal[15] if f % 2 == 0 else pal[14]
				fc.a = clampf(k * 4.0 - float(f) * 0.1, 0.0, 1.0) * fade
				_fx.draw_rect(Rect2(p2.x - 1.0, p2.y - 1.0, 3.0, 3.0), fc)
				_fx.draw_rect(Rect2(p2.x, p2.y - 3.0, 1.0, 7.0), fc)
