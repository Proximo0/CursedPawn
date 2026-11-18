extends Node
## Preview scene: the shop room with six props on the shelves and a customer at the counter, for renders.
## User args after `--`: --room-wake (wake at once), --room-nodither, --room-dread=<n>.

var room: ShopRoom
var run: RunState


func _ready() -> void:
	var cat: Catalog = Catalog.load_default()
	run = RunState.new()
	run.start(11, cat, Tuning.new())
	run.inventory.clear()
	var picks: PackedStringArray = ["Music box", "Silver locket", "Violin", "Old ledger", "Candlestick", "Porcelain doll"]
	var uid: int = 100
	for n: String in picks:
		for o: Dictionary in cat.objects:
			if str(o["name"]) == n:
				run.inventory.append({"uid": uid, "id": o["id"], "name": n, "category": o["category"], "value": o["value"],
					"curse": "", "est": 30, "tells": 0})
				uid += 1
	room = ShopRoom.new()
	add_child(room)
	room.setup(run)
	room.apply_events([{"e": "customer", "kind": "seller", "name": "Hand mirror", "ask": 50}] as Array[Dictionary])
	room.settle_visuals()
	if Flags.args.has("room-nodither"):
		room.dither_enabled = false
	if Flags.args.has("room-dread"):
		room.set_dread(float(Flags.args["room-dread"]))
	if Flags.args.has("room-wake"):
		room.wake(7)
