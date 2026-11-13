extends Control
## Boot: load save, apply settings, show the title screen.

func _ready() -> void:
	var has = Save.load_save()
	if has and Save.data.settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if has: Sys.market_tick()
	UI.reset("title")
