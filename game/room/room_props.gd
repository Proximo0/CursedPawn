class_name RoomProps
extends RefCounted
## Placeholder art for the shop room, all from primitives: props by object category, the hooded customer, a candle,
## the tarot card, plus material and texture helpers. Replace with real art later; the sizes stay the contract.

const COL_AMBER := Color(0.85, 0.54, 0.17)
const COL_PALE_AMBER := Color(0.95, 0.76, 0.35)
const COL_BONE := Color(0.88, 0.84, 0.72)
const COL_WOOD := Color(0.54, 0.31, 0.16)
const COL_DARK_WOOD := Color(0.29, 0.16, 0.10)
const COL_PURPLE := Color(0.36, 0.24, 0.50)
const COL_LIGHT_PURPLE := Color(0.54, 0.42, 0.69)
const COL_GREEN := Color(0.25, 0.42, 0.23)
const COL_SICK_GREEN := Color(0.56, 0.69, 0.29)
const COL_RED := Color(0.78, 0.21, 0.25)
const PROP_SCALE: float = 1.3  ## props are drawn larger than life so they read at 480x270
const CARD_SIZE := Vector3(0.36, 0.012, 0.58)


static func mat(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func ghost_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := mat(Color(color.r, color.g, color.b, alpha), 0.0, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Adds a MeshInstance3D child with a colour. Returns it.
static func part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		emission: float = 0.0, cast_shadow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emission)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(top: float, bottom: float, h: float, segs: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func ball(r: float, segs: int = 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 3)
	return s


## A prop of an object category: {visual: Node3D (centred on its collision box), shape: Shape3D, half_h: float,
## mass: float}. Unknown categories give a grey crate.
static func make(category: String) -> Dictionary:
	var v := Node3D.new()
	var shape: Shape3D
	var half_h: float = 0.1
	match category:
		"toy":  # music box: amber box, lid, key, little tin-soldier green nub
			part(v, box(Vector3(0.26, 0.15, 0.20)), COL_AMBER, Vector3(0, -0.04, 0))
			part(v, box(Vector3(0.28, 0.05, 0.22)), COL_PALE_AMBER, Vector3(0, 0.08, 0))
			part(v, cyl(0.03, 0.03, 0.08), COL_SICK_GREEN, Vector3(0.0, 0.15, 0))
			shape = _box_shape(Vector3(0.28, 0.22, 0.22))
			half_h = 0.11
		"jewelry":  # velvet case with a glowing stone
			part(v, box(Vector3(0.24, 0.12, 0.18)), COL_PURPLE, Vector3(0, -0.02, 0))
			part(v, box(Vector3(0.25, 0.03, 0.19)), COL_BONE, Vector3(0, 0.055, 0))
			part(v, ball(0.045, 8), COL_SICK_GREEN, Vector3(0, 0.12, 0), Vector3.ZERO, 1.4)
			shape = _box_shape(Vector3(0.25, 0.20, 0.19))
			half_h = 0.10
		"instrument":  # violin-ish: two bulbs and a neck
			var body := ball(0.11, 10)
			var b1: MeshInstance3D = part(v, body, COL_WOOD, Vector3(-0.07, 0, 0))
			b1.scale = Vector3(1.0, 0.55, 0.85)
			var b2: MeshInstance3D = part(v, body, COL_WOOD, Vector3(0.07, 0, 0))
			b2.scale = Vector3(0.8, 0.55, 0.7)
			part(v, box(Vector3(0.22, 0.04, 0.04)), COL_DARK_WOOD, Vector3(0.22, 0.02, 0))
			part(v, box(Vector3(0.05, 0.05, 0.07)), COL_AMBER, Vector3(0.34, 0.03, 0))
			shape = _box_shape(Vector3(0.62, 0.13, 0.20))
			half_h = 0.065
		"book":  # two stacked books, green and purple, pages showing
			part(v, box(Vector3(0.30, 0.07, 0.22)), COL_GREEN, Vector3(0, -0.04, 0))
			part(v, box(Vector3(0.29, 0.05, 0.215)), COL_BONE, Vector3(0.012, -0.04, 0.0))
			part(v, box(Vector3(0.28, 0.06, 0.20)), COL_PURPLE, Vector3(0.01, 0.025, 0))
			part(v, box(Vector3(0.02, 0.065, 0.20)), COL_PALE_AMBER, Vector3(-0.14, 0.025, 0))
			shape = _box_shape(Vector3(0.30, 0.14, 0.22))
			half_h = 0.07
		"relic":  # candlestick with a sickly flame
			part(v, cyl(0.10, 0.12, 0.04), COL_AMBER, Vector3(0, -0.15, 0))
			part(v, cyl(0.025, 0.04, 0.22), COL_PALE_AMBER, Vector3(0, -0.02, 0))
			part(v, cyl(0.06, 0.03, 0.05), COL_AMBER, Vector3(0, 0.12, 0))
			part(v, ball(0.04, 8), COL_SICK_GREEN, Vector3(0, 0.19, 0), Vector3.ZERO, 1.6)
			var cs := CylinderShape3D.new()
			cs.radius = 0.11
			cs.height = 0.40
			shape = cs
			half_h = 0.20
		_:
			part(v, box(Vector3(0.2, 0.2, 0.2)), Color(0.5, 0.5, 0.52), Vector3.ZERO)
			shape = _box_shape(Vector3(0.2, 0.2, 0.2))
			half_h = 0.10
	v.scale = Vector3.ONE * PROP_SCALE
	if shape is BoxShape3D:
		(shape as BoxShape3D).size *= PROP_SCALE
	elif shape is CylinderShape3D:
		(shape as CylinderShape3D).radius *= PROP_SCALE
		(shape as CylinderShape3D).height *= PROP_SCALE
	return {"visual": v, "shape": shape, "half_h": half_h * PROP_SCALE, "mass": 0.6}


static func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


## A frozen-until-woken RigidBody3D prop (visual and one collision shape), origin at the box centre.
static func make_body(category: String, display_name: String) -> Dictionary:
	var d: Dictionary = make(category)
	var body := RigidBody3D.new()
	body.name = "Prop_%s" % display_name.replace(" ", "_")
	body.mass = float(d["mass"])
	body.continuous_cd = true
	body.linear_damp = 0.15
	body.angular_damp = 1.0
	body.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.85
	pm.bounce = 0.12
	body.physics_material_override = pm
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	var cs := CollisionShape3D.new()
	cs.shape = d["shape"]
	body.add_child(cs)
	body.add_child(d["visual"])
	d["body"] = body
	return d


## The hooded, cloaked customer silhouette, facing +Z (the camera). Dark body, void face, two amber eyes.
static func make_customer() -> Node3D:
	var root := Node3D.new()
	root.name = "Customer"
	var cloak_col := Color(0.14, 0.08, 0.22)
	part(root, cyl(0.20, 0.52, 1.45, 12), cloak_col, Vector3(0, 0.725, 0), Vector3.ZERO, 0.0, true)
	part(root, cyl(0.0, 0.24, 0.34, 10), cloak_col, Vector3(0, 1.80, 0), Vector3.ZERO, 0.0, true)
	var hood: MeshInstance3D = part(root, ball(0.27, 12), cloak_col, Vector3(0, 1.55, 0), Vector3.ZERO, 0.0, true)
	hood.scale = Vector3(1.0, 1.1, 1.0)
	var face: MeshInstance3D = part(root, ball(0.19, 10), Color(0.03, 0.02, 0.05), Vector3(0, 1.52, 0.12))
	face.scale = Vector3(0.9, 1.05, 0.8)
	for sx: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = part(root, ball(0.028, 6), COL_PALE_AMBER, Vector3(0.07 * sx, 1.55, 0.255), Vector3.ZERO, 2.5)
		eye.material_override = mat(COL_PALE_AMBER, 2.5, true)
	# a sleeve with a hand holding the cloak shut
	part(root, box(Vector3(0.16, 0.5, 0.16)), cloak_col, Vector3(-0.34, 0.95, 0.12), Vector3(0.0, 0.0, 0.25))
	part(root, box(Vector3(0.16, 0.5, 0.16)), cloak_col, Vector3(0.34, 0.95, 0.12), Vector3(0.0, 0.0, -0.25))
	return root


## A candle: bone stub with a flame. Returns the node; the flame is child "Flame".
static func make_candle() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.04, 0.05, 0.22), COL_BONE, Vector3(0, 0.11, 0))
	var flame: MeshInstance3D = part(root, ball(0.035, 6), COL_PALE_AMBER, Vector3(0, 0.26, 0))
	flame.name = "Flame"
	flame.scale = Vector3(1.0, 1.7, 1.0)
	flame.material_override = mat(COL_PALE_AMBER, 2.0, true)
	return root


## The UV lamp seen during the uv inspection: a stand and a violet cone of light. Child "Beam".
static func make_uv_lamp() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.05, 0.05, 0.9), COL_DARK_WOOD, Vector3(0.45, 0.45, 0))
	part(root, box(Vector3(0.5, 0.05, 0.05)), COL_DARK_WOOD, Vector3(0.2, 0.9, 0))
	part(root, cyl(0.1, 0.04, 0.12), COL_LIGHT_PURPLE, Vector3(-0.02, 0.88, 0), Vector3.ZERO, 1.5)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cyl(0.36, 0.05, 0.8, 12)
	beam.material_override = ghost_mat(Color(0.62, 0.35, 0.95), 0.42)
	beam.position = Vector3(-0.02, 0.42, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	return root


## A small balance scale. Children "Beam" (tips about Z).
static func make_scale() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.16, 0.2, 0.05), COL_AMBER, Vector3(0, 0.025, 0))
	part(root, cyl(0.03, 0.03, 0.5), COL_AMBER, Vector3(0, 0.27, 0))
	var beam := Node3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0, 0.54, 0)
	root.add_child(beam)
	part(beam, box(Vector3(0.7, 0.04, 0.04)), COL_PALE_AMBER, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		part(beam, cyl(0.12, 0.02, 0.06), COL_PALE_AMBER, Vector3(0.34 * sx, -0.22, 0))
		part(beam, box(Vector3(0.015, 0.2, 0.015)), COL_BONE, Vector3(0.34 * sx, -0.11, 0))
	return root


## Tarot card: a thin box with a textured back (down) and face (up). Child "Pivot" holds everything.
static func make_card(face_hue: int) -> Node3D:
	var root := Node3D.new()
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)
	part(pivot, box(CARD_SIZE), COL_BONE, Vector3.ZERO)
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CARD_SIZE.x * 0.94, CARD_SIZE.z * 0.94)
	back.mesh = q
	back.material_override = _card_mat(card_texture(false, face_hue))
	back.position = Vector3(0, -CARD_SIZE.y * 0.5 - 0.002, 0)
	back.rotation = Vector3(PI * 0.5, 0, 0)
	pivot.add_child(back)
	var face := MeshInstance3D.new()
	face.mesh = q
	face.material_override = _card_mat(card_texture(true, face_hue))
	face.position = Vector3(0, CARD_SIZE.y * 0.5 + 0.002, 0)
	face.rotation = Vector3(-PI * 0.5, 0, 0)
	pivot.add_child(face)
	return root


static func _card_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := mat(Color.WHITE)
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


## 24x40 pixel card art drawn in code. `face` false is the purple back pattern.
static func card_texture(face: bool, hue: int) -> ImageTexture:
	var w: int = 24
	var h: int = 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base: Color = COL_BONE if face else COL_PURPLE
	var ink: Color = [COL_RED, COL_GREEN, COL_PURPLE][absi(hue) % 3] if face else COL_PALE_AMBER
	img.fill(base)
	for x: int in range(w):
		for y: int in range(h):
			var edge: bool = x < 2 or y < 2 or x >= w - 2 or y >= h - 2
			if edge:
				img.set_pixel(x, y, ink)
				continue
			var dx: int = absi(x - w / 2)
			var dy: int = absi(y - h / 2)
			if face:
				if dx + dy * 6 / 10 < 7 and dx + dy * 6 / 10 > 3:
					img.set_pixel(x, y, ink)
			elif (x + y) % 4 == 0:
				img.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(img)


## Floor planks (nearest filtered, tiled).
static func plank_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var shades: Array[Color] = [Color(0.36, 0.20, 0.12), Color(0.31, 0.17, 0.10), Color(0.40, 0.23, 0.13), Color(0.33, 0.19, 0.12)]
	for y: int in range(32):
		var row: int = y / 8
		for x: int in range(32):
			var c: Color = shades[(row * 5 + (x + row * 11) / 16) % 4]
			if y % 8 == 0 or (x + row * 11) % 16 == 0:
				c = Color(0.16, 0.09, 0.07)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Wallpaper: vertical bands of two deep purples with a thin green line.
static func wall_texture() -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	for x: int in range(16):
		var c: Color = Color(0.30, 0.20, 0.42) if x < 8 else Color(0.25, 0.16, 0.36)
		if x == 0 or x == 8:
			c = Color(0.20, 0.34, 0.25)
		for y: int in range(8):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
