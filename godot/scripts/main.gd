extends Control
## Boot: load save, apply settings, show the title screen.

func _ready() -> void:
	var has = Save.load_save()
	if has and Save.data.settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not OS.has_feature("web") and not Cloud.companion():
		_fit_window()
	if has: Sys.market_tick()
	UI.reset("title")
	_cloud_check()

## PC: never open bigger than the screen — fill the usable area (taskbar excluded), maximised, keeping the game's shape
func _fit_window() -> void:
	var scr: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(scr)
	if usable.size.x <= 0: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	# fallback for systems that ignore maximise: size the window to the usable area
	await get_tree().process_frame
	var ws: Vector2i = DisplayServer.window_get_size()
	if ws.x > usable.size.x or ws.y > usable.size.y:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var sz = Vector2i(int(usable.size.x * 0.96), int(usable.size.y * 0.94))
		DisplayServer.window_set_size(sz)
		DisplayServer.window_set_position(usable.position + (usable.size - sz) / 2)

## download newer progress (e.g. from the companion app) before you start playing
func _cloud_check() -> void:
	if not Cloud.signed_in(): return
	var r = await Cloud.check_newer()
	if r == "pulled": UI.toast("Downloaded newer progress from the cloud", "good"); UI.rerender()
	elif r == "conflict": await UI.modules[0].resolve_conflict()

func _notification(what: int) -> void:
	# companion: coming back to the browser tab picks up anything played in the game meanwhile
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and Cloud.companion() and is_inside_tree(): _cloud_check()
