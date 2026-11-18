class_name TuningPanel
extends CanvasLayer
## Live tuning panel (F1). Built from Tuning.FIELDS, grouped; edits Tuning.shared().

const PRESET_PATH: String = "user://tuning_preset.json"

var _tuning: Tuning = Tuning.shared()
var _panel: PanelContainer
var _sliders: Dictionary = {}  ## field -> HSlider
var _labels: Dictionary = {}  ## field -> Label
var _status: Label


func _init() -> void:
	layer = 50


func _ready() -> void:
	_build()
	_panel.visible = false
	_refresh_all()


func toggle() -> void:
	_panel.visible = not _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 8)
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.size = Vector2(400, 560)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Tuning (F1 hides)"
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(384, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var group: String = ""
	for f: Array in Tuning.FIELDS:
		if str(f[5]) != group:
			group = str(f[5])
			var head := Label.new()
			head.text = "-- %s --" % group
			head.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
			list.add_child(head)
		list.add_child(_tp_row(f))
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_tp_button(buttons, "Reset", _on_reset)
	_tp_button(buttons, "Save preset", _on_save)
	_tp_button(buttons, "Load preset", _on_load)
	_status = Label.new()
	box.add_child(_status)


func _tp_row(f: Array) -> Control:
	var row := HBoxContainer.new()
	row.tooltip_text = str(f[6])
	var name_label := Label.new()
	name_label.text = str(f[0])
	name_label.custom_minimum_size = Vector2(140, 0)
	name_label.tooltip_text = str(f[6])
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = float(f[2])
	slider.max_value = float(f[3])
	slider.step = float(f[4])
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = str(f[6])
	slider.value_changed.connect(_on_slider.bind(str(f[0])))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_sliders[str(f[0])] = slider
	_labels[str(f[0])] = value_label
	return row


func _tp_button(parent: Control, text: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)


func _on_slider(value: float, field: String) -> void:
	_tuning.set_value(field, value)
	_labels[field].text = _tp_fmt(float(_tuning.get(field)))


func _refresh_all() -> void:
	for field: String in _sliders:
		var v: float = float(_tuning.get(field))
		(_sliders[field] as HSlider).set_value_no_signal(v)
		(_labels[field] as Label).text = _tp_fmt(v)


static func _tp_fmt(v: float) -> String:
	return str(snappedf(v, 0.01))


func _on_reset() -> void:
	_tuning.reset()
	_refresh_all()
	_status.text = "Reset to defaults"


func _on_save() -> void:
	var err: Error = _tuning.save_json(PRESET_PATH)
	_status.text = "Saved %s" % PRESET_PATH if err == OK else "Save failed (%d)" % err


func _on_load() -> void:
	var ok: bool = _tuning.load_json(PRESET_PATH)
	_refresh_all()
	_status.text = "Loaded preset" if ok else "No preset found"
