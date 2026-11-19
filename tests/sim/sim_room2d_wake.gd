extends "res://tests/sim/sim_base.gd"
## 2D room wake: after wake() every body stays inside the room and above the floor, all bodies come to rest
## (speed < 2 px/s) within 8 s, and two wakes with the same seed end within 1 px. Also checks the props moved.

const PROPS: int = 14
const ROOM_W: float = 640.0
const ROOM_FLOOR: float = 300.0
const REST_SPEED: float = 2.0
const SAME_TOL: float = 1.0


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


func _out_of_bounds(room: ShopRoom2D) -> bool:
	for b: RigidBody2D in room.all_bodies():
		if b.position.x < 0.0 or b.position.x > ROOM_W or b.position.y > ROOM_FLOOR + 2.0 or b.position.y < -10.0:
			return true
	return false


## Runs one wake; returns {oob, settle_s, final_speed, moved, pos}.
func _one_wake(seed_value: int, broke: String = "") -> Dictionary:
	var room := ShopRoom2D.new()
	room.show_screen = false
	world.add_child(room)
	room.setup(_make_run())
	await step(30)  # props sit on their shelves
	var before: Array[Vector2] = []
	for b: RigidBody2D in room.prop_bodies():
		before.append(b.position)
	if broke != "":
		room.apply_events([{"e": "wake", "night": 2, "dread": 3.0, "broke": room.prop_names()[0], "closed": false}] as Array[Dictionary])
	else:
		room.wake(seed_value)
	var oob: bool = false
	var settle_s: float = -1.0
	for tick: int in range(8 * 60 + 30):
		await step(1)
		if _out_of_bounds(room):
			oob = true
		if settle_s < 0.0 and tick > 60 and room.max_body_speed() < REST_SPEED and not room.is_waking():
			settle_s = float(tick) / 60.0
	var pos: Array[Vector2] = []
	var moved: int = 0
	var i: int = 0
	for b: RigidBody2D in room.all_bodies():
		pos.append(b.position)
		if i < before.size() and b.position.distance_to(before[i]) > 20.0:
			moved += 1
		i += 1
	var final_speed: float = room.max_body_speed()
	world.remove_child(room)
	room.free()
	await step(2)
	return {"oob": oob, "settle_s": settle_s, "pos": pos, "moved": moved, "final_speed": final_speed}


func run() -> Array:
	await sandbox()
	var a: Dictionary = await _one_wake(1234)
	var b: Dictionary = await _one_wake(1234)
	var c: Dictionary = await _one_wake(99)
	var d: Dictionary = await _one_wake(0, "shatter")
	var err: float = 0.0
	var diff: float = 0.0
	for i: int in range((a["pos"] as Array).size()):
		err = maxf(err, ((a["pos"] as Array)[i] as Vector2).distance_to(((b["pos"] as Array)[i] as Vector2)))
		diff = maxf(diff, ((a["pos"] as Array)[i] as Vector2).distance_to(((c["pos"] as Array)[i] as Vector2)))
	var rows: Array = []
	rows.append(row("room2d_wake_props_moved", int(a["moved"]) >= PROPS / 2, "moved %d of %d" % [int(a["moved"]), PROPS]))
	rows.append(row("room2d_wake_stays_in_room", not bool(a["oob"]) and not bool(b["oob"]), "out of bounds: %s" % str(a["oob"])))
	rows.append(row("room2d_wake_rests_within_8s", float(a["settle_s"]) >= 0.0 and float(a["final_speed"]) < REST_SPEED,
		"settled at %.2f s, final speed %.4f px/s" % [float(a["settle_s"]), float(a["final_speed"])]))
	rows.append(row("room2d_wake_same_seed_same_result", err < SAME_TOL, "max position error %.4f px" % err))
	rows.append(row("room2d_wake_other_seed_differs", diff > 5.0, "max difference %.1f px" % diff))
	rows.append(row("room2d_wake_shatter_rests_in_room", not bool(d["oob"]) and float(d["settle_s"]) >= 0.0,
		"out of bounds %s, settled at %.2f s" % [str(d["oob"]), float(d["settle_s"])]))
	await clear()
	return rows
