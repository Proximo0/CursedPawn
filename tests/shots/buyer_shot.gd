extends SceneTree
## One frame before and one after the counter of the BUYER OFFERS tile. /tmp/shots/buyer_offer.png
## xvfb-run -a godot --path . -s res://tests/shots/buyer_shot.gd -- --scripted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var g: Node = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(g)
	for _i: int in range(10):
		await process_frame
	g.open_test_menu()
	for _i: int in range(10):
		await process_frame
	g.run_test_tile("buyer_offer")
	for _i: int in range(25):
		await process_frame
	var a: Image = root.get_viewport().get_texture().get_image()
	for _i: int in range(60):
		await process_frame
	var b: Image = root.get_viewport().get_texture().get_image()
	var out := Image.create(a.get_width(), a.get_height() * 2, false, a.get_format())
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, a.get_height()))
	out.save_png("/tmp/shots/buyer_offer.png")
	print("SHOT done")
	quit()
