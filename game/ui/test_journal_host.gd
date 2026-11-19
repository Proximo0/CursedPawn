class_name TestJournalHost
extends TsScreen
## Hosts the Ledger (journal) book on its own for the test menu: opens it at once, and leaving the book closes the host.

signal closed


func ts_ready() -> void:
	ts_open_ledger()


func ts_close_ledger() -> void:
	closed.emit()


func ts_escape_menu() -> void:
	closed.emit()


func ts_draw_scene(c: TsCanvas) -> void:
	c.fill(Rect2(Vector2.ZERO, ShopGame.VIEW), 0)
