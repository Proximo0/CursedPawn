class_name TsHintTracker
extends RefCounted
## Holds the hint on screen: picks one with TutorialHints.next, marks it seen at once (so it never returns, even if
## the game is closed mid-hint), keeps it for SHOW_SECS, then clears it. ShopGame calls refresh() after every state
## change and tick() each frame; the HUD draws text() with TsHintFrame.

const SHOW_SECS: float = 9.0

var settings: TsSettings
var current: Dictionary = {}
var age: float = 0.0


func _init(settings_in: TsSettings = null) -> void:
	settings = settings_in if settings_in != null else TsSettings.shared()


func refresh(run: RunState) -> void:
	if not current.is_empty():
		return
	var h: Dictionary = TutorialHints.next(run, settings.seen)
	if h.is_empty():
		return
	current = h
	age = 0.0
	settings.mark_seen(str(h["id"]))
	settings.save_player()


func tick(delta: float) -> void:
	if current.is_empty():
		return
	age += delta
	if age >= SHOW_SECS:
		dismiss()


func dismiss() -> void:
	current = {}


func text() -> String:
	return str(current.get("text", ""))
