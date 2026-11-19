class_name StoreArt
extends RefCounted
## Store page art (docs/full_game_plan.md step 38): Steam capsules composed from the game's own render plus the DISPLAY
## font, at the sizes Steam asks for. Pure image work: tests/shots/store_art.gd captures the source frames from the real
## room and calls `compose()`. Everything stays on the 16-colour palette (integer upscales, dithered shading, palette-cut
## text), so a capsule looks like the game. Nothing here uploads anything.
##
## kinds -> size: header 920x430, small 462x174, main 1232x706, vertical 748x896, library 600x900, hero 3840x1240 (art
## only: Steam draws the logo over it), logo 1280x720 (transparent).

const SIZES: Dictionary = {
	"header": Vector2i(920, 430), "small": Vector2i(462, 174), "main": Vector2i(1232, 706), "vertical": Vector2i(748, 896),
	"library": Vector2i(600, 900), "hero": Vector2i(3840, 1240), "logo": Vector2i(1280, 720),
}
const TITLE: String = "CURSED PAWN"
const TAGLINE: String = "AN OCCULT PAWNSHOP"
const GOLD: PackedInt32Array = [11, 15, 10, 12]  ## DISPLAY colours [main, highlight, lowlight, shadow]
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func size_of(kind: String) -> Vector2i:
	return SIZES.get(kind, Vector2i(920, 430)) as Vector2i


## DISPLAY-font text rendered into a transparent Image at an integer `scale`, with its bevel and drop shadow.
static func text_image(text: String, scale: int, cols: PackedInt32Array = GOLD) -> Image:
	var wide: int = UiPixelFont.ui_display_width(text, scale)
	var img: Image = Image.create_empty(maxi(wide + 4 * scale, 1), UiPixelFont.HEAD_ROWS * scale + 3 * scale, false, Image.FORMAT_RGBA8)
	var x: int = 0
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		var adv: int = UiPixelFont.ui_text_width(UiPixelFont.HEAD, text.substr(i, 1), scale)
		if UiPixelFont.ui_head_supports(text.substr(i, 1)):
			var tex: Image = UiPixelFont.ui_display_tex(code, scale, cols).get_image()
			img.blend_rect(tex, Rect2i(Vector2i.ZERO, tex.get_size()), Vector2i(x, scale))
		x += adv
	return img


## The largest integer text scale whose width fits `max_w`.
static func fit_scale(text: String, max_w: int, max_scale: int = 12) -> int:
	var s: int = max_scale
	while s > 1 and UiPixelFont.ui_display_width(text, s) > max_w:
		s -= 1
	return s


## `src` upscaled by an integer factor so it covers (w, h), then cropped around the focus point (0..1 of the source).
static func cover(src: Image, w: int, h: int, focus: Vector2) -> Image:
	var k: int = maxi(ceili(float(w) / float(src.get_width())), ceili(float(h) / float(src.get_height())))
	var big: Image = src.duplicate()
	big.resize(src.get_width() * k, src.get_height() * k, Image.INTERPOLATE_NEAREST)
	var x0: int = clampi(roundi(focus.x * float(big.get_width()) - float(w) * 0.5), 0, maxi(big.get_width() - w, 0))
	var y0: int = clampi(roundi(focus.y * float(big.get_height()) - float(h) * 0.5), 0, maxi(big.get_height() - h, 0))
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(big, Rect2i(x0, y0, w, h), Vector2i.ZERO)
	return out


## Dithered shade toward palette colour `col`, strongest at `from_y` fading to nothing at `to_y` (either direction).
static func shade(img: Image, from_y: int, to_y: int, col: int, strength: float, step: int = 3) -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var c: Color = pal[col]
	var lo: int = mini(from_y, to_y)
	var hi: int = maxi(from_y, to_y)
	for y: int in range(maxi(lo, 0), mini(hi, img.get_height())):
		var f: float = float(y - from_y) / float(to_y - from_y)
		var k: float = strength * (1.0 - clampf(f, 0.0, 1.0))
		for x: int in range(img.get_width()):
			var thr: float = float(BAYER[((y / step) % 4) * 4 + ((x / step) % 4)]) / 16.0
			if k > thr:
				img.fill_rect(Rect2i(x, y, 1, 1), c)


static func blend_centered(dst: Image, src: Image, cx: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(cx - src.get_width() / 2, y))


## A figure sprite at an integer scale, standing with its feet at `base_y`, centred on cx.
static func place_sprite(dst: Image, sprite: Image, scale: int, cx: int, base_y: int) -> void:
	var big: Image = sprite.duplicate()
	big.resize(sprite.get_width() * scale, sprite.get_height() * scale, Image.INTERPOLATE_NEAREST)
	dst.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(cx - big.get_width() / 2, base_y - big.get_height()))


## The logo: TITLE big over TAGLINE small, on transparency, with a thin gilt rule between. Used alone and inside capsules.
static func logo_image(width: int, with_tagline: bool = true) -> Image:
	var s: int = fit_scale(TITLE, width - 8)
	var t: Image = text_image(TITLE, s)
	var ts: int = maxi(s / 3, 1)
	var sub: Image = text_image(TAGLINE, fit_scale(TAGLINE, t.get_width() * 3 / 4, ts), [14, 15, 4, 0] as PackedInt32Array)
	var gap: int = s * 2
	var h: int = t.get_height() + (gap + sub.get_height() if with_tagline else 0)
	var out: Image = Image.create_empty(maxi(t.get_width(), sub.get_width()), h, false, Image.FORMAT_RGBA8)
	blend_centered(out, t, out.get_width() / 2, 0)
	if with_tagline:
		var rule_y: int = t.get_height() + gap / 3
		var rw: int = t.get_width() * 3 / 4
		var pal: PackedColorArray = RoomPalette.colors()
		out.fill_rect(Rect2i((out.get_width() - rw) / 2, rule_y, rw, maxi(s / 4, 1)), pal[10])
		out.fill_rect(Rect2i((out.get_width() - rw) / 2, rule_y, rw, 1), pal[11])
		blend_centered(out, sub, out.get_width() / 2, t.get_height() + gap)
	return out


## Composes one store image. `shots` holds source frames at any size with the room's 16:9 look: "room" (the shop, a
## customer at the counter), "dread" (high Dread, eyes in the dark), "collector" (the Collector at the counter) and
## "tableau" (an ending illustration, 640x360); `customer` is a 64x96 figure image. Missing keys fall back to "room".
static func compose(kind: String, shots: Dictionary, customer: Image) -> Image:
	var sz: Vector2i = size_of(kind)
	var room: Image = shots.get("room", Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)) as Image
	var dread: Image = shots.get("dread", room) as Image
	var coll: Image = shots.get("collector", room) as Image
	var tab: Image = shots.get("tableau", room) as Image
	if kind == "logo":
		var lg: Image = Image.create_empty(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		var l: Image = logo_image(sz.x - 120)
		blend_centered(lg, l, sz.x / 2, (sz.y - l.get_height()) / 2)
		return lg
	var out: Image
	match kind:
		"vertical", "library":
			out = cover(coll, sz.x, sz.y, Vector2(0.78, 0.55))
			shade(out, 0, sz.y * 2 / 5, 0, 0.9)
			shade(out, sz.y, sz.y * 3 / 5, 0, 0.85)
			var l2: Image = logo_image(sz.x - 90)
			place_sprite(out, customer, 7, sz.x / 2, sz.y - 6)
			blend_centered(out, l2, sz.x / 2, sz.y / 14)
		"hero":
			out = cover(tab, sz.x, sz.y, Vector2(0.5, 0.5))
			shade(out, sz.y, sz.y / 2, 0, 0.6)
			shade(out, 0, sz.y / 4, 0, 0.5)
		"main":
			out = cover(room, sz.x, sz.y, Vector2(0.62, 0.55))
			shade(out, sz.y, sz.y * 11 / 20, 0, 0.9)
			shade(out, 0, sz.y / 5, 0, 0.5)
			var l3: Image = logo_image(sz.x * 11 / 20)
			blend_centered(out, l3, sz.x * 3 / 10, sz.y - l3.get_height() - sz.y / 12)
			place_sprite(out, customer, 5, sz.x * 17 / 20, sz.y * 19 / 20)
		"small":
			out = cover(dread, sz.x, sz.y, Vector2(0.6, 0.5))
			shade(out, 0, sz.y, 0, 0.55)
			var l4: Image = logo_image(sz.x - 40, false)
			blend_centered(out, l4, sz.x / 2, (sz.y - l4.get_height()) / 2)
		_:  # header
			out = cover(room, sz.x, sz.y, Vector2(0.64, 0.55))
			shade(out, sz.y, sz.y / 3, 0, 0.9)
			shade(out, 0, sz.y / 4, 0, 0.5)
			var l5: Image = logo_image(sz.x * 3 / 5)
			blend_centered(out, l5, sz.x * 3 / 10 + 8, sz.y - l5.get_height() - sz.y / 12)
			place_sprite(out, customer, 3, sz.x * 17 / 20, sz.y - 6)
	out.convert(Image.FORMAT_RGBA8)
	return out
