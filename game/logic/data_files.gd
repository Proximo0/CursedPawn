class_name DataFiles
extends RefCounted
## Small helpers for the engagement data files (hauntings, omens, requests): reading JSON and applying the shared
## {set, mul, flags} rule shape onto a Tuning.


static func read_array(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		for d: Variant in parsed:
			if d is Dictionary:
				out.append(d)
	return out


static func read_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Applies an entry's `set` then `mul` to `tun` (values clamp to each field's range).
static func apply_rule(tun: Tuning, rule: Dictionary) -> void:
	var sets: Dictionary = rule.get("set", {})
	for field: Variant in sets:
		tun.set_value(str(field), float(sets[field]))
	var muls: Dictionary = rule.get("mul", {})
	for field: Variant in muls:
		tun.set_value(str(field), float(tun.get(str(field))) * float(muls[field]))


## Problems with one entry: unknown tuning fields, unknown flags, text of 70 characters or more.
static func rule_problems(label: String, rule: Dictionary, known_flags: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for key: String in ["set", "mul"]:
		for field: Variant in (rule.get(key, {}) as Dictionary):
			if Tuning.field_info(str(field)).is_empty():
				out.append("%s: unknown tuning field %s" % [label, field])
	for flag: Variant in (rule.get("flags", {}) as Dictionary):
		if not known_flags.has(str(flag)):
			out.append("%s: unknown flag %s" % [label, flag])
	var text: String = str(rule.get("text", ""))
	if text == "" or text.length() >= 70:
		out.append("%s: text must be 1-69 characters (%d)" % [label, text.length()])
	if str(rule.get("name", "")) == "":
		out.append("%s: no name" % label)
	return out
