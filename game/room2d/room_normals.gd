class_name RoomNormals
extends RefCounted
## Procedural normal maps for the pixel art: a height estimate (luminance plus a bevel at transparent edges) is turned
## into a normal map, and both are wrapped in a CanvasTexture so 2D lights rake across the surface. Cached per key.

static var _rn_cache: Dictionary = {}


## Wraps `tex` in a CanvasTexture with a derived normal map. `wrap` samples neighbours with wraparound (tiles).
static func canvas_texture(key: String, tex: Texture2D, strength: float = 1.6, wrap: bool = false) -> CanvasTexture:
	if _rn_cache.has(key):
		return _rn_cache[key] as CanvasTexture
	var ct := CanvasTexture.new()
	ct.diffuse_texture = tex
	ct.normal_texture = ImageTexture.create_from_image(normal_image(tex.get_image(), strength, wrap))
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rn_cache[key] = ct
	return ct


## Height = luminance minus a bevel along transparent edges; normal = (-dh/dx, +dh/dy, 1) normalised (Y up).
static func normal_image(src: Image, strength: float, wrap: bool) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var hs := PackedFloat32Array()
	hs.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			var c: Color = src.get_pixel(x, y)
			var v: float = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a
			if c.a < 0.5:
				v = -0.6
			elif not wrap:
				var edge: bool = false
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h or src.get_pixel(nx, ny).a < 0.5:
						edge = true
						break
				if edge:
					v -= 0.5
			hs[y * w + x] = v
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		for x: int in range(w):
			var xl: int = (x - 1 + w) % w if wrap else maxi(x - 1, 0)
			var xr: int = (x + 1) % w if wrap else mini(x + 1, w - 1)
			var yu: int = (y - 1 + h) % h if wrap else maxi(y - 1, 0)
			var yd: int = (y + 1) % h if wrap else mini(y + 1, h - 1)
			var dx: float = hs[y * w + xr] - hs[y * w + xl]
			var dy: float = hs[yd * w + x] - hs[yu * w + x]
			var n := Vector3(-dx * strength, dy * strength, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, src.get_pixel(x, y).a))
	return out
