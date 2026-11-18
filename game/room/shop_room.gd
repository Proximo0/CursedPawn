class_name ShopRoom
extends Node3D
## The one-room pawnshop: fixed camera, low-poly 3D drawn into a 480x270 SubViewport and shown full screen through
## a 16-colour palette + 4x4 Bayer dither shader. Built entirely in code. Contract: docs/room_brief.md.
##   setup(run)        fill the shelves with one prop per held item
##   apply_events(ev)  react to RunState events
##   set_dread(v)      flicker and fog grow with Dread
##   wake(seed)        deterministic chaos for WAKE_SECS (physics-tick driven, so replays look the same)
## Metres, Y up, -Z forward. The camera stands behind the counter; the customer faces it.

signal wake_finished

const VIEW_SIZE := Vector2i(480, 270)
const WAKE_SECS: float = 4.0
const TICKS_PER_SEC: int = 60
const ROOM_W: float = 6.0
const ROOM_D: float = 5.0
const ROOM_H: float = 3.0
const COUNTER_TOP: float = 1.06
const COUNTER_OBJ_POS := Vector3(0.8, 0.0, 0.1)
const STAND_POS := Vector3(0.8, 0.0, -0.85)
const DOOR_POS := Vector3(-2.55, 0.0, -1.2)
const DOOR_HINGE := Vector3(-2.96, 0.0, -0.7)
const DOOR_OPEN_ANGLE: float = -1.45
const CAMERA_POS := Vector3(0.0, 2.5, 2.45)
const CAMERA_LOOK := Vector3(0.0, 1.0, -1.3)
const CAMERA_FOV: float = 62.0
const BOARD_TOPS: Array[float] = [0.42, 1.02, 1.62]
const TIER_ORDER: Array[int] = [1, 2, 0]
const UNIT_HEIGHT: float = 2.15
const UNIT_DEPTH: float = 0.42
const SHELF_MASS: float = 30.0
const FX_SECS: float = 1.3
const CARD_FLIP_SECS: float = 0.9
const WALK_SPEED: float = 2.4
const LIGHT_RISE_PER_SEC: float = 0.6
const LIGHT_FALL_PER_SEC: float = 3.0
const RED_FADE_PER_SEC: float = 0.35
const FLOOR_SLOTS: int = 8
const AMBER_LIGHT := Color(1.0, 0.62, 0.26)
const RED_LIGHT := Color(1.0, 0.16, 0.12)
const UV_COLOR := Color(0.62, 0.30, 1.0)

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
var _world: Node3D
var _cam: Camera3D
var _env: Environment
var _lights: Array[Dictionary] = []
var _uv_light: OmniLight3D
var _door: Node3D
var _door_angle: float = 0.0
var _door_target: float = 0.0
var _units: Array[RigidBody3D] = []
var _slots: Array[Dictionary] = []
var _slot_used: Dictionary = {}  ## slot index -> uid
var _dead_unit: int = -1  ## index of the toppled shelf unit (its slots are unusable)
var _props: Dictionary = {}  ## uid -> {uid, name, category, body, half_h, slot}
var _next_loose_uid: int = -1
var _slides: Array[Dictionary] = []
var _shards: Array[RigidBody3D] = []

var _customer: Node3D
var _cust_state: String = "none"  ## none, enter, here, leave
var _cust_pos: Vector3 = Vector3.ZERO
var _carry: bool = false
var _counter_obj: Node3D
var _counter_cat: String = ""
var _counter_root: Node3D
var _fx_kind: String = ""
var _fx_t: float = 0.0
var _fx_uv: Node3D
var _fx_scale: Node3D
var _fx_rings: Array[MeshInstance3D] = []
var _fx_frost: Node3D
var _card: Node3D
var _card_t: float = -1.0

var _t: float = 0.0
var _level: float = 1.0
var _level_target: float = 1.0
var _red: float = 0.0
var _wake_level: float = 1.0
var _shake: float = 0.0
var _wake_tick: int = -1
var _wake_plan: Array[Dictionary] = []
var _plan_i: int = 0
var _topple_unit: int = -1
var _topple_left: int = 0
var _doomed: RigidBody3D
var _wake_rng := RandomNumberGenerator.new()
var _wakes_done: int = 0
var _lights_red_done: bool = false


func _init() -> void:
	name = "ShopRoom"
	_build_view()
	_rebuild_world()


func _build_view() -> void:
	_vp = SubViewport.new()
	_vp.name = "RoomViewport"
	_vp.size = VIEW_SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
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
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
		_add_prop(int(item["uid"]), str(item["name"]), str(item["category"]), false)
	set_dread(run.dread)
	if not run.customer.is_empty() and not run.is_over():
		var cat: String = ""
		if str(run.customer.get("kind", "")) == RunState.SELLER:
			cat = str((run.customer.get("item", {}) as Dictionary).get("category", ""))
		_cust_start_enter(cat)
		_cust_state = "here"
		_cust_pos = STAND_POS
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
				var cat: String = ""
				if str(e.get("kind", "")) == RunState.SELLER:
					cat = _category_of_name(str(e.get("name", "")))
				_cust_start_enter(cat)
			"passed", "left":
				_cust_start_leave(false)
			"bought":
				_on_bought(e)
				_cust_start_leave(false)
			"sold":
				_on_sold(e)
				_cust_start_leave(true)
			"inspected":
				_start_fx(str(e.get("tool", "")))
			"wager":
				_start_card(str(e.get("card", "")))
			"wake":
				_on_wake_event(e)
			"night_end":
				_cust_start_leave(false)
				_level = minf(_level, 0.2)
				_level_target = 0.2
			"run_lost":
				_cust_start_leave(false)
				_level = minf(_level, 0.25)
				_level_target = 0.06
			"run_won":
				_cust_start_leave(false)
				_level_target = 1.35
			_:
				pass


## Deterministic chaos for about WAKE_SECS: shelf props are unfrozen and shoved off, one shelf topples, the lights die
## and come back red, the door slams. Same seed and same props give the same result.
func wake(seed_value: int) -> void:
	_wake_rng.seed = seed_value
	_wake_plan.clear()
	_plan_i = 0
	_wake_tick = 0
	_wakes_done += 1
	_slides.clear()
	_lights_red_done = false
	var n: int = 0
	if _cust_state != "none":
		_finish_leave()
	_hide_fx()
	var bodies: Array[RigidBody3D] = []
	for rec: Dictionary in _props.values():
		bodies.append(rec["body"] as RigidBody3D)
	if _doomed != null:
		bodies.append(_doomed)
	for body: RigidBody3D in bodies:
		body.freeze = false
		var wall: String = str(body.get_meta("wall", "back"))
		var delay: float = _wake_rng.randf_range(0.2, 2.4)
		var speed: float = _wake_rng.randf_range(2.2, 4.6)
		var lat: float = _wake_rng.randf_range(-0.5, 0.5)
		var lift: float = _wake_rng.randf_range(0.3, 1.1)
		var spin := Vector3(_wake_rng.randf_range(-1.0, 1.0), _wake_rng.randf_range(-1.0, 1.0), _wake_rng.randf_range(-1.0, 1.0))
		var skip: float = _wake_rng.randf()
		if skip < 0.1 and body != _doomed:
			continue
		var dir := Vector3(lat, 0.0, 1.0)
		if wall == "right":
			dir = Vector3(-1.0, 0.0, lat)
		var impulse: Vector3 = (dir.normalized() * speed + Vector3(0, lift, 0)) * body.mass
		n += 1
		_plan_add(int(delay * TICKS_PER_SEC), "shove", body, impulse, spin * 0.06)
	var cands: Array[int] = []
	for i: int in range(_units.size()):
		if str(_units[i].get_meta("wall", "back")) == "back":
			cands.append(i)
	if not cands.is_empty():
		var pick: int = cands[_wake_rng.randi_range(0, cands.size() - 1)]
		_plan_add(int(1.35 * TICKS_PER_SEC), "topple", null, Vector3(float(pick), 0, 0), Vector3.ZERO)
	if _doomed != null:
		var shards: Array = []
		for i: int in range(6):
			shards.append({"v": Vector3(_wake_rng.randf_range(-1.5, 1.5), _wake_rng.randf_range(1.0, 3.0), _wake_rng.randf_range(0.0, 2.5)),
				"s": _wake_rng.randf_range(0.04, 0.09)})
		_plan_add(int(1.8 * TICKS_PER_SEC), "shatter", _doomed, Vector3.ZERO, Vector3.ZERO, shards)
	_plan_add(int(WAKE_SECS * TICKS_PER_SEC), "end", null, Vector3.ZERO, Vector3.ZERO)
	_wake_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["t"]) < int(b["t"]) or (int(a["t"]) == int(b["t"]) and int(a["n"]) < int(b["n"])))


func is_waking() -> bool:
	return _wake_tick >= 0


func prop_count() -> int:
	return _props.size()


func prop_bodies() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	for rec: Dictionary in _props.values():
		out.append(rec["body"] as RigidBody3D)
	return out


func prop_names() -> PackedStringArray:
	var out := PackedStringArray()
	for rec: Dictionary in _props.values():
		out.append(str(rec["name"]))
	return out


func customer_state() -> String:
	return _cust_state


func has_card() -> bool:
	return _card != null and _card.visible


func fx_kind() -> String:
	return _fx_kind


func light_level() -> float:
	return _level


func camera() -> Camera3D:
	return _cam


func viewport() -> SubViewport:
	return _vp


## The largest linear speed among the props (m/s); 0 when there are none.
func max_prop_speed() -> float:
	var m: float = 0.0
	for rec: Dictionary in _props.values():
		m = maxf(m, ((rec["body"] as RigidBody3D).linear_velocity).length())
	return m


## Jumps animations to their ends (customer arrived or gone, effects done, lights settled). For tests and shots.
func settle_visuals() -> void:
	if _cust_state == "enter":
		_cust_state = "here"
		_cust_pos = STAND_POS
		_show_counter_object()
	elif _cust_state == "leave":
		_finish_leave()
	_level = _level_target
	_slides.clear()


# ---------------------------------------------------------------- frame loop

func _physics_process(_delta: float) -> void:
	if _wake_tick < 0:
		return
	while _plan_i < _wake_plan.size() and int(_wake_plan[_plan_i]["t"]) <= _wake_tick:
		_run_plan_entry(_wake_plan[_plan_i])
		_plan_i += 1
	if _topple_left > 0 and _topple_unit >= 0:
		_topple_left -= 1
		var u: RigidBody3D = _units[_topple_unit]
		u.apply_force(Vector3(0, 0, SHELF_MASS * 9.0), Vector3(0, 1.9, 0))
	_wake_light_and_door(_wake_tick)
	_wake_tick += 1


func _process(delta: float) -> void:
	_t += delta
	if _wake_tick < 0:
		var rate: float = LIGHT_RISE_PER_SEC if _level_target > _level else LIGHT_FALL_PER_SEC
		_level = move_toward(_level, _level_target, delta * rate)
		_red = move_toward(_red, 0.0, delta * RED_FADE_PER_SEC)
		_wake_level = 1.0
		_door_angle = lerpf(_door_angle, _door_target, minf(delta * 6.0, 1.0))
	_shake = maxf(_shake - delta * 1.6, 0.0)
	_update_customer(delta)
	_update_slides(delta)
	_update_fx(delta)
	_update_card(delta)
	_update_door()
	_update_lights()
	_update_camera()


func _run_plan_entry(p: Dictionary) -> void:
	var body: RigidBody3D = p["body"] as RigidBody3D if p["body"] != null else null
	match str(p["k"]):
		"shove":
			if is_instance_valid(body):
				body.apply_central_impulse(p["v"] as Vector3)
				body.apply_torque_impulse(p["w"] as Vector3)
		"topple":
			var idx: int = int((p["v"] as Vector3).x)
			if idx >= 0 and idx < _units.size():
				_topple_unit = idx
				_dead_unit = idx
				var u: RigidBody3D = _units[idx]
				u.freeze = false
				u.apply_impulse(Vector3(0, 0, SHELF_MASS * 0.8), Vector3(0, 1.9, 0))
				_topple_left = 45
				_shake = maxf(_shake, 0.6)
		"shatter":
			if is_instance_valid(body):
				_shatter(body, p["shards"] as Array)
		"end":
			_wake_tick = -2
			_wake_level = 1.0
			wake_finished.emit()


func _wake_light_and_door(t: int) -> void:
	var s: float = float(t) / float(TICKS_PER_SEC)
	if s < 0.35:
		_wake_level = 1.0 - 0.6 * absf(sin(float(t) * 0.9))
		_red = 0.0
	elif s < 0.8:
		_wake_level = 0.10
		_red = 1.0
		if s > 0.55 and s < 0.62:
			_wake_level = 0.6  # a red flash in the dark
	elif s < 1.5:
		_wake_level = lerpf(0.10, 1.7, (s - 0.8) / 0.7)
		_red = 1.0
	else:
		_wake_level = lerpf(1.7, 1.0, clampf((s - 1.5) / 1.0, 0.0, 1.0))
		_red = 1.0
	if s < 0.8:
		_door_angle = 0.03 * sin(float(t) * 1.7)
	elif s < 1.0:
		_door_angle = lerpf(0.0, DOOR_OPEN_ANGLE, (s - 0.8) / 0.2)
	elif s < 2.0:
		_door_angle = DOOR_OPEN_ANGLE + 0.08 * sin(s * 7.0)
	elif s < 2.15:
		var u: float = (s - 2.0) / 0.15
		_door_angle = lerpf(DOOR_OPEN_ANGLE, 0.0, u * u)
		if t == int(2.15 * TICKS_PER_SEC) - 1:
			_shake = 1.0
	else:
		_door_angle = 0.0
	_door_target = 0.0


# ---------------------------------------------------------------- world

func _rebuild_world() -> void:
	if _world != null:
		_vp.remove_child(_world)
		if _world.is_inside_tree():
			_world.queue_free()
		else:
			_world.free()
	_world = Node3D.new()
	_world.name = "World"
	_vp.add_child(_world)
	_lights.clear()
	_units.clear()
	_slots.clear()
	_slot_used.clear()
	_props.clear()
	_slides.clear()
	_shards.clear()
	_dead_unit = -1
	_wake_tick = -1
	_wake_plan.clear()
	_plan_i = 0
	_topple_left = 0
	_topple_unit = -1
	_doomed = null
	_cust_state = "none"
	_carry = false
	_counter_cat = ""
	_fx_kind = ""
	_card_t = -1.0
	_level = 1.0
	_level_target = 1.0
	_red = 0.0
	_wake_level = 1.0
	_door_angle = 0.0
	_door_target = 0.0
	_build_environment()
	_build_shell()
	_build_shelves()
	_build_counter()
	_build_door()
	_build_lights()
	_build_customer()
	_build_camera()


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.04, 0.03, 0.07)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.42, 0.70)
	_env.ambient_light_energy = 0.7
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_light_color = Color(0.22, 0.40, 0.25)
	_env.fog_density = 0.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)


func _static_box(parent: Node3D, size: Vector3, pos: Vector3, mesh_color: Variant = null) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	if mesh_color != null:
		RoomProps.part(sb, RoomProps.box(size), mesh_color as Color, Vector3.ZERO, Vector3.ZERO, 0.0, true)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.1
	sb.physics_material_override = pm
	parent.add_child(sb)
	return sb


func _textured_quad(size: Vector2, tex: Texture2D, uv_scale: Vector2, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := RoomProps.mat(Color.WHITE)
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mi)
	return mi


func _build_shell() -> void:
	var hw: float = ROOM_W * 0.5
	var hd: float = ROOM_D * 0.5
	# colliders (floor thick, so nothing tunnels out); the front and ceiling are invisible
	_static_box(_world, Vector3(ROOM_W + 2.0, 1.0, ROOM_D + 2.0), Vector3(0, -0.5, 0))
	_static_box(_world, Vector3(0.4, ROOM_H + 1.0, ROOM_D + 1.0), Vector3(-hw - 0.2, ROOM_H * 0.5, 0))
	_static_box(_world, Vector3(0.4, ROOM_H + 1.0, ROOM_D + 1.0), Vector3(hw + 0.2, ROOM_H * 0.5, 0))
	_static_box(_world, Vector3(ROOM_W + 1.0, ROOM_H + 1.0, 0.4), Vector3(0, ROOM_H * 0.5, -hd - 0.2))
	_static_box(_world, Vector3(ROOM_W + 1.0, ROOM_H + 1.0, 0.4), Vector3(0, ROOM_H * 0.5, hd + 0.2))
	_static_box(_world, Vector3(ROOM_W + 1.0, 0.4, ROOM_D + 1.0), Vector3(0, ROOM_H + 0.2, 0))
	# visible surfaces
	var floor_mesh: MeshInstance3D = _textured_quad(Vector2(ROOM_W, ROOM_D), RoomProps.plank_texture(),
		Vector2(ROOM_W * 1.2, ROOM_D * 1.2), Vector3(0, 0.0, 0), Vector3(-PI * 0.5, 0, 0))
	floor_mesh.name = "FloorMesh"
	var wall_tex: ImageTexture = RoomProps.wall_texture()
	_textured_quad(Vector2(ROOM_W, ROOM_H), wall_tex, Vector2(ROOM_W * 2.0, 1.0), Vector3(0, ROOM_H * 0.5, -hd), Vector3.ZERO)
	_textured_quad(Vector2(ROOM_D, ROOM_H), wall_tex, Vector2(ROOM_D * 2.0, 1.0), Vector3(-hw, ROOM_H * 0.5, 0), Vector3(0, PI * 0.5, 0))
	_textured_quad(Vector2(ROOM_D, ROOM_H), wall_tex, Vector2(ROOM_D * 2.0, 1.0), Vector3(hw, ROOM_H * 0.5, 0), Vector3(0, -PI * 0.5, 0))
	var ceil_mesh: MeshInstance3D = _textured_quad(Vector2(ROOM_W, ROOM_D), RoomProps.wall_texture(), Vector2(2, 2),
		Vector3(0, ROOM_H, 0), Vector3(PI * 0.5, 0, 0))
	ceil_mesh.material_override = RoomProps.mat(Color(0.12, 0.08, 0.17))
	for bz: float in [-1.6, 0.0, 1.6]:  # ceiling beams
		RoomProps.part(_world, RoomProps.box(Vector3(ROOM_W, 0.16, 0.2)), RoomProps.COL_DARK_WOOD, Vector3(0, ROOM_H - 0.08, bz))
	# skirting along the walls and a rug under the customer
	RoomProps.part(_world, RoomProps.box(Vector3(ROOM_W, 0.18, 0.05)), RoomProps.COL_DARK_WOOD, Vector3(0, 0.09, -hd + 0.03))
	RoomProps.part(_world, RoomProps.box(Vector3(2.8, 0.02, 1.8)), Color(0.26, 0.38, 0.22), Vector3(0.5, 0.012, -0.6))
	RoomProps.part(_world, RoomProps.box(Vector3(2.5, 0.025, 1.5)), Color(0.42, 0.22, 0.28), Vector3(0.5, 0.02, -0.6))


func _build_counter() -> void:
	_static_box(_world, Vector3(4.8, 1.0, 0.7), Vector3(0, 0.5, 0.1), Color(0.34, 0.19, 0.11))
	RoomProps.part(_world, RoomProps.box(Vector3(5.0, 0.07, 0.85)), Color(0.30, 0.17, 0.10), Vector3(0, 1.03, 0.1), Vector3.ZERO, 0.0, true)
	# front panel trim facing the customer side
	RoomProps.part(_world, RoomProps.box(Vector3(4.4, 0.5, 0.03)), RoomProps.COL_DARK_WOOD, Vector3(0, 0.55, -0.26))
	var candle: Node3D = RoomProps.make_candle()
	candle.position = Vector3(-1.6, COUNTER_TOP, 0.0)
	_world.add_child(candle)
	var bell := Node3D.new()
	bell.position = Vector3(-0.55, COUNTER_TOP, 0.0)
	RoomProps.part(bell, RoomProps.cyl(0.0, 0.09, 0.1, 8), RoomProps.COL_PALE_AMBER, Vector3(0, 0.05, 0))
	_world.add_child(bell)
	_counter_root = Node3D.new()
	_counter_root.position = Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP, COUNTER_OBJ_POS.z)
	_world.add_child(_counter_root)
	# tool effects, all hidden until an inspected event
	_fx_uv = RoomProps.make_uv_lamp()
	_fx_uv.position = Vector3(COUNTER_OBJ_POS.x - 0.1, COUNTER_TOP, COUNTER_OBJ_POS.z + 0.25)
	_fx_uv.visible = false
	_world.add_child(_fx_uv)
	_fx_scale = RoomProps.make_scale()
	_fx_scale.position = Vector3(COUNTER_OBJ_POS.x + 0.85, COUNTER_TOP, COUNTER_OBJ_POS.z)
	_fx_scale.visible = false
	_world.add_child(_fx_scale)
	_fx_rings.clear()
	for i: int in range(3):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.22
		tm.outer_radius = 0.27
		tm.rings = 16
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = RoomProps.ghost_mat(RoomProps.COL_BONE, 0.8)
		ring.position = Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP + 0.03, COUNTER_OBJ_POS.z)
		ring.visible = false
		_world.add_child(ring)
		_fx_rings.append(ring)
	_fx_frost = Node3D.new()
	_fx_frost.position = Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP, COUNTER_OBJ_POS.z)
	_fx_frost.visible = false
	_world.add_child(_fx_frost)
	var frost_mat: StandardMaterial3D = RoomProps.ghost_mat(Color(0.85, 0.95, 0.9), 0.55)
	for i: int in range(7):
		var shard := MeshInstance3D.new()
		shard.mesh = RoomProps.cyl(0.0, 0.05, 0.3, 5)
		shard.material_override = frost_mat
		var a: float = float(i) / 7.0 * TAU
		shard.position = Vector3(cos(a) * 0.2, 0.12, sin(a) * 0.2)
		shard.rotation = Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx_frost.add_child(shard)
	var dome := MeshInstance3D.new()
	dome.mesh = RoomProps.ball(0.26, 10)
	dome.material_override = frost_mat
	dome.position = Vector3(0, 0.13, 0)
	dome.name = "Dome"
	_fx_frost.add_child(dome)
	_uv_light = OmniLight3D.new()
	_uv_light.light_color = UV_COLOR
	_uv_light.omni_range = 2.6
	_uv_light.light_energy = 0.0
	_uv_light.position = Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP + 0.5, COUNTER_OBJ_POS.z)
	_world.add_child(_uv_light)
	_card = null


func _build_door() -> void:
	var z0: float = DOOR_HINGE.z
	# a dark doorway and a frame in the left wall
	RoomProps.part(_world, RoomProps.box(Vector3(0.06, 2.2, 1.08)), Color(0.08, 0.10, 0.12), Vector3(-2.97, 1.1, z0 - 0.5))
	RoomProps.part(_world, RoomProps.box(Vector3(0.12, 0.12, 1.3)), RoomProps.COL_DARK_WOOD, Vector3(-2.93, 2.22, z0 - 0.5))
	RoomProps.part(_world, RoomProps.box(Vector3(0.12, 2.2, 0.1)), RoomProps.COL_DARK_WOOD, Vector3(-2.93, 1.1, z0 + 0.05))
	RoomProps.part(_world, RoomProps.box(Vector3(0.12, 2.2, 0.1)), RoomProps.COL_DARK_WOOD, Vector3(-2.93, 1.1, z0 - 1.05))
	_door = Node3D.new()
	_door.position = Vector3(DOOR_HINGE.x + 0.04, 0.0, z0)
	_world.add_child(_door)
	RoomProps.part(_door, RoomProps.box(Vector3(0.07, 2.1, 1.0)), Color(0.50, 0.28, 0.14), Vector3(0, 1.05, -0.5), Vector3.ZERO, 0.0, true)
	RoomProps.part(_door, RoomProps.box(Vector3(0.09, 0.8, 0.62)), Color(0.38, 0.21, 0.11), Vector3(0.0, 1.35, -0.5))
	RoomProps.part(_door, RoomProps.ball(0.05, 6), RoomProps.COL_PALE_AMBER, Vector3(0.07, 1.0, -0.88))


func _build_shelves() -> void:
	# unit: [x, z, yaw, length, slots per tier, wall]
	var defs: Array = [
		[0.0, -2.28, 0.0, 1.8, 2, "back"],
		[-1.9, -2.28, 0.0, 1.8, 2, "back"],
		[1.9, -2.28, 0.0, 1.8, 2, "back"],
		[2.78, -0.7, -PI * 0.5, 1.6, 2, "right"],
	]
	var unit_slots: Array = []
	for d: Array in defs:
		var u: RigidBody3D = _build_unit(Vector3(float(d[0]), 0.0, float(d[1])), float(d[2]), float(d[3]), str(d[5]))
		_units.append(u)
		var local: Array[Vector3] = []
		var n: int = int(d[4])
		var length: float = float(d[3])
		for tier: int in TIER_ORDER:
			for s: int in range(n):
				var lx: float = (float(s) - float(n - 1) * 0.5) * ((length - 0.25) / float(n))
				local.append(Vector3(lx, BOARD_TOPS[tier], 0.02))
		unit_slots.append(local)
	# interleave so the first props land on visible shelves: centre, left, right-back, right wall
	for ui: int in range(_units.size()):
		for p: Vector3 in unit_slots[ui] as Array:
			_slots.append({"pos": _units[ui].transform * p, "unit": ui, "wall": str(_units[ui].get_meta("wall", "back"))})
	for i: int in range(FLOOR_SLOTS):
		_slots.append({"pos": Vector3(-2.4 + float(i) * 0.68, 0.0, -1.7), "unit": -1, "wall": "back"})


func _build_unit(pos: Vector3, yaw: float, length: float, wall: String) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "ShelfUnit"
	body.mass = SHELF_MASS
	body.position = pos
	body.rotation.y = yaw
	body.continuous_cd = true
	body.can_sleep = true
	body.angular_damp = 0.6
	body.linear_damp = 0.2
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.set_meta("wall", wall)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	body.physics_material_override = pm
	var wood: Color = Color(0.46, 0.26, 0.14)
	var dark: Color = Color(0.30, 0.17, 0.10)
	for top: float in BOARD_TOPS:
		_unit_box(body, Vector3(length, 0.05, UNIT_DEPTH), Vector3(0, top - 0.025, 0), wood)
	_unit_box(body, Vector3(length, 0.05, UNIT_DEPTH), Vector3(0, UNIT_HEIGHT - 0.025, 0), dark)
	_unit_box(body, Vector3(length, 0.1, UNIT_DEPTH), Vector3(0, 0.05, 0), dark)
	for sx: float in [-1.0, 1.0]:
		_unit_box(body, Vector3(0.06, UNIT_HEIGHT, UNIT_DEPTH), Vector3(sx * (length * 0.5 - 0.03), UNIT_HEIGHT * 0.5, 0), dark)
	_unit_box(body, Vector3(length, UNIT_HEIGHT, 0.03), Vector3(0, UNIT_HEIGHT * 0.5, -UNIT_DEPTH * 0.5 + 0.015), Color(0.20, 0.12, 0.17))
	_world.add_child(body)
	return body


func _unit_box(body: RigidBody3D, size: Vector3, center: Vector3, color: Color) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	body.add_child(cs)
	RoomProps.part(body, RoomProps.box(size), color, center, Vector3.ZERO, 0.0, true)


func _build_lights() -> void:
	_add_light(OmniLight3D.new(), Vector3(-1.6, 1.7, 0.35), AMBER_LIGHT, 1.3, 6.0, 0.0)
	_add_light(OmniLight3D.new(), Vector3(-1.9, 2.05, -1.8), AMBER_LIGHT, 1.7, 5.0, 1.7)
	_add_light(OmniLight3D.new(), Vector3(1.9, 2.05, -1.8), AMBER_LIGHT, 1.7, 5.0, 3.1)
	_add_light(OmniLight3D.new(), Vector3(0.0, 2.7, 0.2), Color(1.0, 0.80, 0.50), 1.3, 8.0, 4.4)
	var spot := SpotLight3D.new()
	spot.spot_angle = 50.0
	spot.spot_range = 8.0
	spot.shadow_enabled = true
	spot.rotation = Vector3(-1.2, 0.0, 0.0)
	_add_light(spot, Vector3(0.2, 2.8, 1.4), Color(1.0, 0.86, 0.6), 1.6, 8.0, 0.7)


func _add_light(l: Light3D, pos: Vector3, color: Color, energy: float, light_range: float, phase: float) -> void:
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	if l is OmniLight3D:
		(l as OmniLight3D).omni_range = light_range
	_world.add_child(l)
	_lights.append({"node": l, "color": color, "energy": energy, "phase": phase})


func _build_customer() -> void:
	_customer = RoomProps.make_customer()
	_customer.visible = false
	_world.add_child(_customer)
	_counter_obj = null


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = CAMERA_FOV
	_cam.near = 0.1
	_cam.far = 20.0
	_cam.position = CAMERA_POS
	_cam.current = true
	_world.add_child(_cam)
	_cam.look_at_from_position(CAMERA_POS, CAMERA_LOOK, Vector3.UP)


# ---------------------------------------------------------------- props

func _category_of_name(item_name: String) -> String:
	if run != null and run.catalog != null:
		for o: Dictionary in run.catalog.objects:
			if str(o["name"]) == item_name:
				return str(o["category"])
	return ""


func _free_slot() -> int:
	for i: int in range(_slots.size()):
		if _slot_used.has(i):
			continue
		if int(_slots[i]["unit"]) >= 0 and int(_slots[i]["unit"]) == _dead_unit:
			continue
		return i
	return -1


func _add_prop(uid: int, prop_name: String, category: String, slide: bool) -> void:
	if _props.has(uid):
		return
	var d: Dictionary = RoomProps.make_body(category, prop_name)
	var body: RigidBody3D = d["body"] as RigidBody3D
	var half_h: float = float(d["half_h"])
	var si: int = _free_slot()
	var pos: Vector3 = Vector3(0, half_h, -1.7)
	var wall: String = "back"
	if si >= 0:
		pos = (_slots[si]["pos"] as Vector3) + Vector3(0, half_h + 0.01, 0)
		wall = str(_slots[si]["wall"])
		_slot_used[si] = uid
	body.set_meta("wall", wall)
	body.position = pos
	if wall == "right":
		body.rotation.y = -PI * 0.5
	_world.add_child(body)
	_props[uid] = {"uid": uid, "name": prop_name, "category": category, "body": body, "half_h": half_h, "slot": si}
	if slide:
		_slides.append({"body": body, "from": Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP + half_h, COUNTER_OBJ_POS.z), "to": pos, "t": 0.0})
		body.position = Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP + half_h, COUNTER_OBJ_POS.z)


func _remove_prop(uid: int) -> void:
	if not _props.has(uid):
		return
	var rec: Dictionary = _props[uid]
	_props.erase(uid)
	var si: int = int(rec["slot"])
	if si >= 0:
		_slot_used.erase(si)
	var body: RigidBody3D = rec["body"] as RigidBody3D
	for i: int in range(_slides.size() - 1, -1, -1):
		if _slides[i]["body"] == body:
			_slides.remove_at(i)
	_free_node(body)


func _free_node(n: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	if n.is_inside_tree():
		n.queue_free()
	else:
		n.free()


func _on_bought(e: Dictionary) -> void:
	var uid: int = int(e.get("uid", -1))
	var cat: String = ""
	if run != null:
		for item: Dictionary in run.inventory:
			if int(item["uid"]) == uid:
				cat = str(item["category"])
	if cat == "":
		cat = _counter_cat if _counter_cat != "" else _category_of_name(str(e.get("name", "")))
	_add_prop(uid, str(e.get("name", "?")), cat, true)
	_hide_counter_object()


func _on_sold(e: Dictionary) -> void:
	var uid: int = int(e.get("uid", -1))
	var cat: String = ""
	if _props.has(uid):
		cat = str(_props[uid]["category"])
	elif run != null:
		cat = _category_of_name(str(e.get("name", "")))
	_remove_prop(uid)
	_counter_cat = cat
	_show_counter_object()


func _on_wake_event(e: Dictionary) -> void:
	var broke: String = str(e.get("broke", ""))
	_doomed = null
	if broke != "":
		for uid: Variant in _props:
			if str(_props[uid]["name"]) == broke:
				var rec: Dictionary = _props[uid]
				_props.erase(uid)
				if int(rec["slot"]) >= 0:
					_slot_used.erase(int(rec["slot"]))
				_doomed = rec["body"] as RigidBody3D
				break
	var seed_value: int = int(e.get("night", 0)) * 7919 + int(round(float(e.get("dread", 0.0)) * 100.0)) * 31
	if run != null:
		seed_value += run.seed_used * 104729
	wake(seed_value)


func _plan_add(tick: int, kind: String, body: Variant, v: Vector3, w: Vector3, shards: Array = []) -> void:
	_wake_plan.append({"t": tick, "n": _wake_plan.size(), "k": kind, "body": body, "v": v, "w": w, "shards": shards})


func _shatter(body: RigidBody3D, shards: Array) -> void:
	var at: Vector3 = body.global_position if body.is_inside_tree() else body.position
	var col := Color(0.8, 0.7, 0.5)
	for s: Dictionary in shards:
		var sh := RigidBody3D.new()
		sh.mass = 0.05
		sh.position = at
		sh.linear_velocity = s["v"] as Vector3
		sh.linear_damp = 0.2
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		var sz: float = float(s["s"])
		b.size = Vector3(sz, sz * 0.5, sz)
		cs.shape = b
		sh.add_child(cs)
		RoomProps.part(sh, RoomProps.box(b.size), col, Vector3.ZERO)
		_world.add_child(sh)
		_shards.append(sh)
	if body == _doomed:
		_doomed = null
	_free_node(body)


func _update_slides(delta: float) -> void:
	for i: int in range(_slides.size() - 1, -1, -1):
		var s: Dictionary = _slides[i]
		var body: RigidBody3D = s["body"] as RigidBody3D
		if not is_instance_valid(body) or _wake_tick >= 0:
			_slides.remove_at(i)
			continue
		var t: float = minf(float(s["t"]) + delta / 0.5, 1.0)
		s["t"] = t
		var p: Vector3 = (s["from"] as Vector3).lerp(s["to"] as Vector3, t)
		p.y += sin(t * PI) * 0.35
		body.position = p
		if t >= 1.0:
			body.position = s["to"] as Vector3
			_slides.remove_at(i)


# ---------------------------------------------------------------- customer and counter object

func _cust_start_enter(category: String) -> void:
	if _cust_state == "leave":
		_finish_leave()
	_hide_counter_object()
	_counter_cat = category
	_cust_state = "enter"
	_carry = false
	_cust_pos = DOOR_POS
	_door_target = -0.7
	_place_customer()


func _cust_start_leave(carry: bool) -> void:
	if _cust_state == "none" or _cust_state == "leave":
		return
	_cust_state = "leave"
	_carry = carry
	if not carry:
		_hide_counter_object()
	_door_target = -0.7


func _finish_leave() -> void:
	_cust_state = "none"
	_carry = false
	_customer.visible = false
	_hide_counter_object()
	_door_target = 0.0


func _update_customer(delta: float) -> void:
	match _cust_state:
		"enter":
			_cust_pos = _cust_pos.move_toward(STAND_POS, WALK_SPEED * delta)
			if _cust_pos.distance_to(STAND_POS) < 0.001:
				_cust_state = "here"
				_door_target = 0.0
				_show_counter_object()
		"leave":
			_cust_pos = _cust_pos.move_toward(DOOR_POS, WALK_SPEED * delta)
			if _cust_pos.distance_to(DOOR_POS) < 0.001:
				_finish_leave()
	_place_customer()


func _place_customer() -> void:
	if _customer == null:
		return
	_customer.visible = _cust_state != "none"
	var bob: float = 0.0
	var lean: float = 0.0
	if _cust_state == "enter" or _cust_state == "leave":
		bob = absf(sin(_t * 9.0)) * 0.05
		lean = sin(_t * 4.5) * 0.06
	else:
		bob = sin(_t * 1.6) * 0.012
	_customer.position = _cust_pos + Vector3(0, bob, 0)
	_customer.rotation = Vector3(0, 0, lean)
	if _carry and _counter_obj != null:
		_counter_obj.position = _customer.position + Vector3(0.05, 0.95, 0.4)


func _show_counter_object() -> void:
	_hide_counter_object()
	if _counter_cat == "":
		return
	var d: Dictionary = RoomProps.make(_counter_cat)
	_counter_obj = d["visual"] as Node3D
	_counter_obj.position = Vector3(COUNTER_OBJ_POS.x, COUNTER_TOP + float(d["half_h"]) + 0.005, COUNTER_OBJ_POS.z)
	_world.add_child(_counter_obj)


func _hide_counter_object() -> void:
	if _counter_obj != null:
		_free_node(_counter_obj)
		_counter_obj = null


# ---------------------------------------------------------------- tool effects and tarot

func _start_fx(tool: String) -> void:
	_hide_fx()
	if not ["uv", "scale", "listen", "touch"].has(tool):
		return
	_fx_kind = tool
	_fx_t = 0.0


func _hide_fx() -> void:
	_fx_kind = ""
	_fx_t = 0.0
	if _fx_uv == null:
		return
	_fx_uv.visible = false
	_fx_scale.visible = false
	_fx_frost.visible = false
	for r: MeshInstance3D in _fx_rings:
		r.visible = false
	_uv_light.light_energy = 0.0


func _update_fx(delta: float) -> void:
	if _fx_kind == "":
		return
	_fx_t += delta
	var u: float = clampf(_fx_t / FX_SECS, 0.0, 1.0)
	if u >= 1.0:
		_hide_fx()
		return
	var pulse: float = sin(u * PI)
	match _fx_kind:
		"uv":
			_fx_uv.visible = true
			_uv_light.light_energy = 3.0 * pulse
			var beam: Node3D = _fx_uv.get_node("Beam") as Node3D
			beam.scale = Vector3(1.0 + 0.1 * sin(_fx_t * 30.0), 1.0, 1.0 + 0.1 * sin(_fx_t * 30.0))
		"scale":
			_fx_scale.visible = true
			var beam: Node3D = _fx_scale.get_node("Beam") as Node3D
			beam.rotation.z = 0.4 * sin(u * PI * 3.0) * (1.0 - u)
		"listen":
			for i: int in range(_fx_rings.size()):
				var ring: MeshInstance3D = _fx_rings[i]
				var k: float = clampf(u * 1.6 - float(i) * 0.25, 0.0, 1.0)
				ring.visible = k > 0.0 and k < 1.0
				ring.scale = Vector3.ONE * (0.6 + k * 2.4)
				(ring.material_override as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - k)
		"touch":
			_fx_frost.visible = true
			_fx_frost.scale = Vector3.ONE * (0.4 + 0.9 * minf(u * 3.0, 1.0))
			var dome: MeshInstance3D = _fx_frost.get_node("Dome") as MeshInstance3D
			dome.scale = Vector3.ONE * (1.0 + 0.1 * pulse)


func _start_card(card_name: String) -> void:
	_hide_card()
	var hue: int = 0
	for i: int in range(card_name.length()):
		hue += card_name.unicode_at(i)
	_card = RoomProps.make_card(hue)
	_card.position = Vector3(0.0, COUNTER_TOP + RoomProps.CARD_SIZE.y * 0.5, 0.1)
	_card.rotation.y = 0.2
	_world.add_child(_card)
	_card_t = 0.0
	(_card.get_node("Pivot") as Node3D).rotation.z = 0.0


func _hide_card() -> void:
	if _card != null:
		_free_node(_card)
		_card = null
	_card_t = -1.0


func _update_card(delta: float) -> void:
	if _card == null or _card_t < 0.0:
		return
	_card_t = minf(_card_t + delta, CARD_FLIP_SECS + 5.0)
	var u: float = clampf(_card_t / CARD_FLIP_SECS, 0.0, 1.0)
	var pivot: Node3D = _card.get_node("Pivot") as Node3D
	pivot.rotation.z = PI * u
	pivot.position.y = 0.45 * sin(u * PI)


# ---------------------------------------------------------------- lights, door, camera

func _update_door() -> void:
	if _door != null:
		_door.rotation.y = _door_angle


func _noise(t: float, phase: float) -> float:
	return clampf(0.5 + 0.35 * sin(t * 17.0 + phase) + 0.25 * sin(t * 41.3 + phase * 2.1) + 0.2 * sin(t * 7.1 + phase * 0.7), 0.0, 1.0)


func _update_lights() -> void:
	var dn: float = dread_norm()
	var base_level: float = _level * _wake_level
	for l: Dictionary in _lights:
		var node: Light3D = l["node"] as Light3D
		var ph: float = float(l["phase"])
		var flick: float = 1.0 - 0.06 * _noise(_t, ph)  # candles breathe
		flick -= dn * 0.65 * pow(1.0 - _noise(_t * 1.3, ph), 2.0)
		var col: Color = (l["color"] as Color).lerp(RED_LIGHT, _red * 0.8)
		node.light_color = col
		node.light_energy = float(l["energy"]) * base_level * maxf(flick, 0.0)
	var amb: Color = Color(0.55, 0.42, 0.70).lerp(Color(0.60, 0.22, 0.30), _red * 0.6)
	amb = amb.lerp(Color(0.40, 0.62, 0.42), clampf(dn, 0.0, 1.0) * 0.45 * (1.0 - _red))
	_env.ambient_light_color = amb
	_env.ambient_light_energy = 0.75 * (0.3 + 0.7 * clampf(base_level, 0.0, 1.0))
	_env.fog_density = 0.16 * clampf(dn, 0.0, 1.5) * clampf(dn, 0.0, 1.0)
	_env.fog_light_color = Color(0.22, 0.40, 0.25).lerp(Color(0.35, 0.08, 0.10), _red)


func _update_camera() -> void:
	if _cam == null:
		return
	var amp: float = 0.06 * _shake * _shake
	_cam.position = CAMERA_POS + Vector3(sin(_t * 61.0), cos(_t * 53.0), sin(_t * 47.0) * 0.5) * amp
	_cam.look_at(CAMERA_LOOK + Vector3(sin(_t * 71.0), cos(_t * 67.0), 0.0) * amp * 0.5, Vector3.UP)
