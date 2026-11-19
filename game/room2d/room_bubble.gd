class_name RoomBubble
extends Node2D
## The customer's speech bubble, drawn in code: pops in with a 3-frame squash, types its text out letter by letter
## (emitting `blip` with a per-customer pitch), a pixel tail wobbles, words of dread shiver and drip, and when it
## closes the box frays away into ash pixels. Driven by advance(delta) so tests and sheets are deterministic.

signal blip(pitch: float)

const FONT_SIZE: int = 8
const MAX_TEXT_W: float = 140.0
const PAD_X: float = 5.0
const PAD_Y: float = 3.0
const LINE_H: float = 10.0
const TAIL_H: int = 7
const POP_SECS: float = 0.15
const TYPE_CPS: float = 32.0
const HOLD_SECS: float = 2.0
const FRAY_SECS: float = 0.7
const CELL: int = 3
const SQUASH: Array[Vector2] = [Vector2(1.3, 0.5), Vector2(0.88, 1.22), Vector2(1.04, 0.94)]
const DREAD_WORDS: PackedStringArray = ["cursed", "curse", "dead", "death", "it", "blood", "dark", "hungry", "wake",
	"awake", "ghost", "bones", "grave", "alone"]

var fx: RoomFx
var pitch: float = 1.0
var blip_every: int = 2

var _state: String = "off"  ## off, pop, type, hold, fray
var _t: float = 0.0
var _anim: float = 0.0
var _text: String = ""
var _glyphs: Array[Dictionary] = []  ## {ch, x, y, dread, thr}
var _box := Rect2()
var _tail_x: float = 0.0
var _typed: float = 0.0
var _last_idx: int = -1
var _font: Font


func _init() -> void:
	name = "RoomBubble"
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func is_open() -> bool:
	return _state != "off"


## True while the customer is talking (popping in, typing or holding): the eyes in the dark keep shut.
func is_speaking() -> bool:
	return _state == "pop" or _state == "type" or _state == "hold"


func shown_text() -> String:
	return _text if is_speaking() else ""


func box_rect() -> Rect2:
	return _box


func typed_count() -> int:
	return mini(int(_typed), _glyphs.size())


func _glyph_w(ch: String) -> float:
	return maxf(_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x, 1.0)


func _word_dread(word: String) -> bool:
	var letters: String = ""
	for ch: String in word.to_lower():
		if ch >= "a" and ch <= "z":
			letters += ch
		else:
			break
	return DREAD_WORDS.has(letters)


## Opens the bubble with `text`; `tip` is where the tail points (just above the speaker's head).
func open(text: String, tip: Vector2, view_w: float) -> void:
	_text = text
	_glyphs.clear()
	var x: float = 0.0
	var line: int = 0
	var text_w: float = 0.0
	for word: String in text.split(" ", false):
		var ww: float = 0.0
		for ch: String in word:
			ww += _glyph_w(ch)
		var sp: float = _glyph_w(" ")
		if x > 0.0 and x + ww > MAX_TEXT_W:
			x = 0.0
			line += 1
		var dread: bool = _word_dread(word)
		for ch: String in word:
			_glyphs.append({"ch": ch, "x": x, "y": PAD_Y + float(line) * LINE_H + 7.0, "dread": dread,
				"thr": fposmod(sin(float(_glyphs.size()) * 12.9898) * 43758.5453, 1.0)})
			x += _glyph_w(ch)
		text_w = maxf(text_w, x)
		_glyphs.append({"ch": " ", "x": x, "y": PAD_Y + float(line) * LINE_H + 7.0, "dread": false, "thr": 0.0})
		x += sp
	var size := Vector2(text_w + PAD_X * 2.0, float(line + 1) * LINE_H + PAD_Y * 2.0)
	_box = Rect2(Vector2(clampf(tip.x - size.x * 0.5, 6.0, view_w - 6.0 - size.x), maxf(tip.y - float(TAIL_H) - size.y, 4.0)), size)
	_tail_x = clampf(tip.x - _box.position.x, 8.0, size.x - 8.0)
	_state = "pop"
	_t = 0.0
	_typed = 0.0
	_last_idx = -1
	visible = true
	queue_redraw()


func close() -> void:
	if _state == "off" or _state == "fray":
		return
	_state = "fray"
	_t = 0.0
	queue_redraw()


func hide_now() -> void:
	_state = "off"
	_text = ""
	visible = false


## Skips to the fully typed state (tests, sheets, settle_visuals).
func finish_typing() -> void:
	if _state == "pop" or _state == "type":
		_state = "hold"
		_t = 0.0
		_typed = float(_glyphs.size())
		queue_redraw()


func advance(delta: float) -> void:
	if _state == "off":
		return
	_anim += delta
	_t += delta
	match _state:
		"pop":
			if _t >= POP_SECS:
				_state = "type"
				_t = 0.0
		"type":
			_typed += delta * TYPE_CPS
			var idx: int = mini(int(_typed), _glyphs.size())
			while _last_idx < idx - 1:
				_last_idx += 1
				if str(_glyphs[_last_idx]["ch"]) != " " and _last_idx % blip_every == 0:
					blip.emit(pitch + 0.05 * float(_last_idx % 3))
			if idx >= _glyphs.size():
				_state = "hold"
				_t = 0.0
		"hold":
			if _t >= HOLD_SECS:
				close()
		"fray":
			if fx != null:
				for i: int in range(3):
					fx.emit("ash", _box.position + Vector2(_hash01(_anim * 91.0 + float(i)) * _box.size.x,
						_hash01(_anim * 37.0 + float(i) * 5.0) * _box.size.y), 1)
			if _t >= FRAY_SECS:
				hide_now()
				return
	queue_redraw()


func _hash01(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)


func _draw() -> void:
	if _state == "off":
		return
	var pal: PackedColorArray = RoomPalette.colors()
	var pivot := Vector2(_box.position.x + _tail_x, _box.end.y + float(TAIL_H))
	var scl := Vector2.ONE
	if _state == "pop":
		scl = SQUASH[mini(int(_t / (POP_SECS / 3.0)), 2)]
	draw_set_transform(pivot, 0.0, scl)
	var o: Vector2 = _box.position - pivot
	if _state == "fray":
		_draw_fray(pal, o)
		return
	draw_rect(Rect2(o - Vector2.ONE, _box.size + Vector2(2.0, 2.0)), pal[0])
	draw_rect(Rect2(o, _box.size), pal[15])
	draw_rect(Rect2(o.x + 1.0, o.y + _box.size.y - 1.0, _box.size.x - 2.0, 1.0), pal[14])
	# the tail: a stepped triangle whose tip wobbles
	var cx: float = o.x + _tail_x
	for r: int in range(TAIL_H):
		var w: int = TAIL_H - r
		var wob: float = roundf(sin(_anim * 5.0) * float(r) / float(TAIL_H) * 2.0)
		draw_rect(Rect2(cx + wob - float(w / 2) - 1.0, o.y + _box.size.y + float(r), float(w) + 2.0, 1.0), pal[0])
	for r: int in range(TAIL_H):
		var w2: int = TAIL_H - r
		var wob2: float = roundf(sin(_anim * 5.0) * float(r) / float(TAIL_H) * 2.0)
		draw_rect(Rect2(cx + wob2 - float(w2 / 2), o.y + _box.size.y + float(r), float(w2), 1.0), pal[15])
	_draw_text(pal, o, 0.0)


func _draw_text(pal: PackedColorArray, o: Vector2, fray_k: float) -> void:
	var shown: int = typed_count()
	for i: int in range(shown):
		var g: Dictionary = _glyphs[i]
		var ch: String = str(g["ch"])
		if ch == " ":
			continue
		if fray_k > 0.0 and float(g["thr"]) < fray_k * 1.2:
			continue
		var p: Vector2 = o + Vector2(PAD_X + float(g["x"]), float(g["y"]))
		var col: Color = pal[0]
		if bool(g["dread"]):
			col = pal[12]
			p.x += roundf(sin(_anim * 45.0 + float(i) * 2.1))
			p.y += roundf(sin(_anim * 37.0 + float(i) * 1.3) * 0.6)
			if i % 2 == 0:  # a one-pixel drip that grows and resets
				var drip: float = floorf(fposmod(_anim * 5.0 + float(i) * 1.7, 4.0))
				draw_rect(Rect2(p.x + 1.0, p.y + 2.0, 1.0, drip), pal[12])
		draw_string(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)


func _draw_fray(pal: PackedColorArray, o: Vector2) -> void:
	var k: float = clampf(_t / FRAY_SECS, 0.0, 1.0)
	var nx: int = int(ceilf(_box.size.x / float(CELL)))
	var ny: int = int(ceilf(_box.size.y / float(CELL)))
	for cy: int in range(ny):
		for cx: int in range(nx):
			if _hash01(float(cx * 127 + cy * 311)) < k * 1.05:
				continue
			var edge: bool = cx == 0 or cy == 0 or cx == nx - 1 or cy == ny - 1
			draw_rect(Rect2(o + Vector2(float(cx * CELL), float(cy * CELL)), Vector2(float(CELL), float(CELL))),
				pal[0] if edge else pal[15])
	_draw_text(pal, o, k)
