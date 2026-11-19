class_name BotPilot
extends Node
## --bot=<style> (or ?bot= on the web build): the lab's play-bot plays through the real screen, --bot_steps commands a
## frame (default 1), so act, the room, sound and HUD all run. Stops when the run ends (or after --bot_nights nights), then prints one
## BOT line, sets window.cursedPawnBot on the web (read by tools/web_smoke.mjs) and quits elsewhere (exit 1 when stuck
## or when the recording does not replay). The hash is a string: JavaScript numbers lose a 64-bit int.

var game: ShopGame
var bot: ShopBot
var _reported: bool = false


func _init(game_in: ShopGame, style: String) -> void:
	game = game_in
	bot = ShopBot.new(style)


func _process(_delta: float) -> void:
	var run: RunState = game.run
	var stuck: bool = run.commands >= RunState.MAX_COMMANDS
	var nights: int = int(Flags.get_arg("bot_nights", "99"))
	if not run.is_over() and run.night <= nights and not stuck:
		for i: int in range(maxi(1, int(Flags.get_arg("bot_steps", "1")))):
			if run.is_over() or run.night > nights or run.commands >= RunState.MAX_COMMANDS:
				break
			game.act(bot.decide(run))
		return
	if _reported:
		return
	_reported = true
	var report: Dictionary = bot_report(run, stuck, game.rec.first_divergence(game.catalog))
	print("BOT style=%s seed=%d night=%d cash=%d commands=%d over=%s stuck=%s diverged=%d hash=%s" % [bot.style,
		game.seed_now, run.night, run.cash, run.commands, run.is_over(), stuck, report["diverged"], report["hash"]])
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.cursedPawnBot = %s" % JSON.stringify(report), true)
	else:
		get_tree().quit(0 if bot_ok(report) else 1)


static func bot_report(run: RunState, stuck: bool, diverged: int) -> Dictionary:
	return {"night": run.night, "cash": run.cash, "commands": run.commands, "over": run.is_over(), "won": run.won,
		"stuck": stuck, "diverged": diverged, "hash": str(run.state_hash())}


## A pilot run passes when it was not stuck and its recording replays to the same state at every command.
static func bot_ok(report: Dictionary) -> bool:
	return not bool(report["stuck"]) and int(report["diverged"]) == -1
