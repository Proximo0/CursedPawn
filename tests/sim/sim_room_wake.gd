extends "res://tests/sim/sim_base.gd"
## Room wake: after wake() no prop falls through the floor (4 s), all props come to rest (speed < 0.05 m/s) within 8 s,
## and two wakes with the same seed end with the same prop positions (within 1 cm). Also times the settle.

const PROPS: int = 14
const FLOOR_MIN_Y: float = 0.02
const REST_SPEED: float = 0.05
const SAME_TOL: float = 0.01


func _make_run() -> RunState:
	var cat: Catalog = Catalog.load_default()
	var run := RunState.new()
	run.start(5, cat, Tuning.new())
	run.inventory.clear()
	for i: int in range(PROPS):
		var o: Dictionary = cat.objects[i % cat.objects.size()]
		run.inventory.append({"uid": 10 + i, "id": o["id"], "name": o["name"], "category": o["category"], "value": o["value"],
			"curse": "", "est": 1, "tells": 0})
	return run


## Runs one wake; returns {y_ok, min_y, settle_s, pos: Array[Vector3]}.
func _one_wake(seed_value: int) -> Dictionary:
	var room := ShopRoom.new()
	room.show_screen = false
	world.add_child(room)
	room.setup(_make_run())
	await step(30)  # props sit on their shelves
	var before: Array[Vector3] = []
	for b: RigidBody3D in room.prop_bodies():
		before.append(b.position)
	room.wake(seed_value)
	var min_y: float = 100.0
	var settle_s: float = -1.0
	for tick: int in range(8 * 60 + 30):
		await step(1)
		if tick == 4 * 60:
			for b: RigidBody3D in room.prop_bodies():
				min_y = minf(min_y, b.position.y)
		if settle_s < 0.0 and tick > 60 and room.max_prop_speed() < REST_SPEED and not room.is_waking():
			settle_s = float(tick) / 60.0
	var pos: Array[Vector3] = []
	var moved: int = 0
	var i: int = 0
	for b: RigidBody3D in room.prop_bodies():
		pos.append(b.position)
		if b.position.distance_to(before[i]) > 0.3:
			moved += 1
		i += 1
	var final_speed: float = room.max_prop_speed()
	world.remove_child(room)
	room.free()
	await step(2)
	return {"min_y": min_y, "settle_s": settle_s, "pos": pos, "moved": moved, "final_speed": final_speed}


func run() -> Array:
	await sandbox()
	var a: Dictionary = await _one_wake(1234)
	var b: Dictionary = await _one_wake(1234)
	var c: Dictionary = await _one_wake(99)
	var err: float = 0.0
	for i: int in range((a["pos"] as Array).size()):
		err = maxf(err, ((a["pos"] as Array)[i] as Vector3).distance_to(((b["pos"] as Array)[i] as Vector3)))
	var diff: float = 0.0
	for i: int in range((a["pos"] as Array).size()):
		diff = maxf(diff, ((a["pos"] as Array)[i] as Vector3).distance_to(((c["pos"] as Array)[i] as Vector3)))
	var rows: Array = []
	rows.append(row("room_wake_props_moved", int(a["moved"]) >= PROPS / 2, "moved %d of %d" % [int(a["moved"]), PROPS]))
	rows.append(row("room_wake_no_fall_through", float(a["min_y"]) > FLOOR_MIN_Y, "min y at 4 s %.3f" % float(a["min_y"])))
	rows.append(row("room_wake_rests_within_8s", float(a["settle_s"]) >= 0.0 and float(a["final_speed"]) < REST_SPEED,
		"settled at %.2f s, final speed %.4f" % [float(a["settle_s"]), float(a["final_speed"])]))
	rows.append(row("room_wake_same_seed_same_result", err < SAME_TOL, "max position error %.5f m" % err))
	rows.append(row("room_wake_other_seed_differs", diff > 0.1, "max difference %.2f m" % diff))
	await clear()
	return rows
