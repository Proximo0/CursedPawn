class_name RenderToggles
extends CanvasLayer
## Render diagnostics for hunting GPU-specific glitches on the player's machine. Each function key switches
## one rendering feature off or on, and a line at the bottom of the screen shows what is on. F4 hides the line.
##   F6 particles   F7 MSAA   F8 2D light shadows   F9 2D lights. Add more toggles the same way: a var, a setter, a key, a label part.

const LAYER: int = 127
const FONT_SIZE: int = 15
const PLATE_COLOR := Color(0.05, 0.06, 0.09, 0.8)

var particles: bool = true
var msaa: bool = true
var shadows: bool = true
var lights: bool = true

var _label: Label
var _saved_msaa: Viewport.MSAA = Viewport.MSAA_DISABLED


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE_COLOR
	style.set_content_margin_all(6.0)
	plate.add_theme_stylebox_override("panel", style)
	plate.anchor_left = 0.5
	plate.anchor_right = 0.5
	plate.anchor_top = 1.0
	plate.anchor_bottom = 1.0
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.offset_bottom = -8.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	plate.add_child(_label)
	_saved_msaa = get_viewport().msaa_2d
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F4:
			visible = not visible
		KEY_F6:
			set_particles(not particles)
		KEY_F7:
			set_msaa(not msaa)
		KEY_F8:
			set_shadows(not shadows)
		KEY_F9:
			set_lights(not lights)
		_:
			return
	get_viewport().set_input_as_handled()


func set_particles(on: bool) -> void:
	particles = on
	for n: Node in _all("CPUParticles2D"):
		(n as CPUParticles2D).visible = on
	_refresh()


func set_msaa(on: bool) -> void:
	msaa = on
	get_viewport().msaa_2d = _saved_msaa if on else Viewport.MSAA_DISABLED
	_refresh()


func set_shadows(on: bool) -> void:
	shadows = on
	for n: Node in _all("PointLight2D"):
		(n as PointLight2D).shadow_enabled = on
	_refresh()


func set_lights(on: bool) -> void:
	lights = on
	for n: Node in _all("PointLight2D"):
		(n as PointLight2D).enabled = on
	_refresh()


func _all(type_name: String) -> Array[Node]:
	return get_tree().root.find_children("*", type_name, true, false)


func _refresh() -> void:
	if _label == null:
		return
	var parts: PackedStringArray = [
		"F6 particles %s" % _on(particles), "F7 MSAA %s" % _on(msaa),
		"F8 shadows %s" % _on(shadows), "F9 lights %s" % _on(lights),
		"F4 hide"]
	_label.text = "   ".join(parts)


func _on(v: bool) -> String:
	return "ON" if v else "off"
