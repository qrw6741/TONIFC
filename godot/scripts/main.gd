extends Control
## Boot: load save, apply settings, show the title screen.

func _ready() -> void:
	var has = Save.load_save()
	if has and Save.data.settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if has: Sys.market_tick()
	UI.reset("title")
	_cloud_check()

## download newer progress (e.g. from the companion app) before you start playing
func _cloud_check() -> void:
	if not Cloud.signed_in(): return
	var r = await Cloud.check_newer()
	if r == "pulled": UI.toast("Downloaded newer progress from the cloud", "good"); UI.rerender()
	elif r == "conflict": await UI.modules[0].resolve_conflict()

func _notification(what: int) -> void:
	# companion: coming back to the browser tab picks up anything played in the game meanwhile
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and Cloud.companion() and is_inside_tree(): _cloud_check()
