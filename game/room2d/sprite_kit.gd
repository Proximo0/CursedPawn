class_name SpriteKit
extends RefCounted
## Procedural pixel-art sprites for the 2D shop (docs/room2d_brief.md). STUB: flat boxes until Worker B fills it.


static func object_texture(id: String, category: String) -> ImageTexture:
	return _sk_box(Vector2i(24, 24), Color.from_hsv(float(hash(id + category) % 360) / 360.0, 0.5, 0.8))


static func customer_texture(look: Dictionary) -> ImageTexture:
	return _sk_box(Vector2i(48, int(64.0 * clampf(float(look.get("height", 1.0)), 0.7, 1.3))),
		Color.from_string(str(look.get("cloak", "")), Color(0.14, 0.08, 0.22)))


static func tool_texture(tool: String) -> ImageTexture:
	return _sk_box(Vector2i(16, 16), Color.from_hsv(float(hash(tool) % 360) / 360.0, 0.6, 0.9))


static func card_texture(card_name: String, face_up: bool) -> ImageTexture:
	return _sk_box(Vector2i(24, 40), Color(0.9, 0.85, 0.7) if face_up else Color(0.3, 0.1, 0.4))


static func tile_texture(kind: String) -> ImageTexture:
	return _sk_box(Vector2i(16, 16), Color.from_hsv(float(hash(kind) % 360) / 360.0, 0.3, 0.4))


static func _sk_box(size: Vector2i, c: Color) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
