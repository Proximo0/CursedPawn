class_name DebugOverlay
extends CanvasLayer
## Top-right text overlay of RunState.debug_frame() (F2). Shown by default only with --dev.

var run: RunState
var _label: Label
var _panel: PanelContainer


func _init() -> void:
	layer = 40


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-8, 8)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(300, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_panel.visible = Flags.dev_menu()


func _process(_delta: float) -> void:
	if _panel.visible and run != null:
		_label.text = ov_format(run.debug_frame())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


## The overlay text for one debug_frame() dictionary.
static func ov_format(d: Dictionary) -> String:
	var names: PackedStringArray = []
	for e: Dictionary in d.get("events", []):
		names.append(str(e.get("e", "?")))
	return "night %d  clock %d\ncash %d  rent %d\ndread %.2f  held %d\nkind %s  phase %s\nwakes %d  play %.1f min\ncommands %d\nevents: %s" % [
		int(d.get("night", 0)), int(d.get("clock", 0.0)), int(d.get("cash", 0)), int(d.get("rent", 0)),
		float(d.get("dread", 0.0)), int(d.get("held", 0)), str(d.get("kind", "")), str(d.get("phase", "")),
		int(d.get("wakes", 0)), float(d.get("play_min", 0.0)), int(d.get("commands", 0)), ", ".join(names)]
