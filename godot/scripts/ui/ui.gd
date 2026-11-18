extends Node
## UI — theme, screen router, widgets, modals, toasts and shared dialogs.
## Keyboard / mouse / controller: Godot focus navigation (arrows, D-pad, left stick),
## Enter / A to select, Esc / B to go back, Q/E or LB/RB to switch hub tabs.

const TEXT := Color("#eef2f6")
const DIM := Color("#9aa6b4")
const GOLD := Color("#e8b631")
const GOLD2 := Color("#f6d67a")
const TEAL := Color("#3fe0c5")
const GREEN := Color("#3ddc84")
const YELLOW := Color("#ffd23f")
const RED := Color("#ff4d5e")
const PANEL := Color(0.063, 0.086, 0.118, 0.85)

const HUB_TABS := [["home", "Home"], ["objectives", "Objectives"], ["season", "Season Pass"], ["play", "Play"], ["club", "Club"], ["sbc", "SBC"], ["evolutions", "Evolutions"], ["transfers", "Transfers"], ["store", "Store"]]

var font_head: Font
var font_bold: Font
var font_body: Font
var theme: Theme
var layer: CanvasLayer
var root: Control
var bg: Control
var host: Control
var overlay: Control
var toasts: VBoxContainer
var modules = []
var cur: Control
var cur_name = ""
var cur_params = {}
var cur_back: Callable
var cur_tab = ""
var stack = []
var modals = []
var currency_labels = []
var in_match = false

func _ready() -> void:
	_fonts(); _theme(); _input_map(); apply_display(); _strip_pad_nav()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	layer = CanvasLayer.new(); add_child(layer)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme; root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	bg = preload("res://scripts/ui/menu_bg.gd").new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	host = Control.new(); host.set_anchors_preset(Control.PRESET_FULL_RECT); host.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(host)
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(overlay)
	toasts = VBoxContainer.new(); toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT); toasts.position = Vector2(-430, 80); toasts.custom_minimum_size = Vector2(400, 0)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE; toasts.add_theme_constant_override("separation", 8); root.add_child(toasts)
	modules = [preload("res://scripts/ui/screens/menu.gd").new(), preload("res://scripts/ui/screens/hub.gd").new(), preload("res://scripts/ui/screens/hub2.gd").new(), preload("res://scripts/ui/screens/season_ui.gd").new(), preload("res://scripts/ui/screens/gallery_ui.gd").new(), preload("res://scripts/ui/screens/event_ui.gd").new(), preload("res://scripts/ui/screens/evo_ui.gd").new(), preload("res://scripts/ui/screens/market_ui.gd").new(), preload("res://scripts/ui/screens/champs_ui.gd").new(), preload("res://scripts/ui/screens/sbc_ui.gd").new(), preload("res://scripts/ui/screens/rivals_ui.gd").new(), preload("res://scripts/ui/screens/store_ui.gd").new()]
	Sys.currency_changed.connect(refresh_currency)
	Pad.style_changed.connect(func(): if not in_match and modals.is_empty() and cur_name != "" and cur_name != "results": rerender())
	Sys.toast.connect(toast)
	get_viewport().size_changed.connect(func(): toasts.position = Vector2(root.size.x - 430, 80) if not mobile else Vector2(10, 70))
	_mobile_setup()
	get_tree().node_added.connect(_on_node_added)

func _fonts() -> void:
	var h = SystemFont.new(); h.font_names = PackedStringArray(["Arial Black", "Segoe UI Black", "Impact", "Helvetica Neue", "Arial", "Liberation Sans", "DejaVu Sans"]); h.font_weight = 900
	var b = SystemFont.new(); b.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial", "Liberation Sans", "DejaVu Sans"]); b.font_weight = 800
	var n = SystemFont.new(); n.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial", "Liberation Sans", "DejaVu Sans"]); n.font_weight = 400
	for f in [h, b, n]: f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font_head = h; font_bold = b; font_body = n

func _sb(bg_col: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 10, pad := Vector4(16, 9, 16, 9)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = bg_col; s.border_color = border; s.set_border_width_all(bw); s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s

func _theme() -> void:
	theme = Theme.new()
	theme.default_font = font_body; theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	# buttons
	var variants = {
		"Button": [Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.14), TEXT],
		"Primary": [Color("#eef0ff"), Color(0, 0, 0, 0), Color("#111111")],
		"Gold": [GOLD, Color(0, 0, 0, 0), Color("#1a1406")],
		"Danger": [Color(1, 0.3, 0.37, 0.18), Color(1, 0.3, 0.37, 0.5), TEXT],
		"Small": [Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.14), TEXT],
		"Tile": [Color(0.12, 0.17, 0.21, 0.88), Color(1, 1, 1, 0.09), TEXT],
		"Row": [Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), TEXT],
		"Tab": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(1, 1, 1, 0.55)],
		"MenuItem": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(1, 1, 1, 0.55)],
	}
	for v in variants:
		var bgc: Color = variants[v][0]; var brd: Color = variants[v][1]; var fc: Color = variants[v][2]
		if v != "Button": theme.set_type_variation(v, "Button")
		var pad = Vector4(10, 6, 10, 6) if v == "Small" else (Vector4(22, 18, 22, 18) if v == "Tile" else (Vector4(14, 8, 14, 8) if v == "Row" else (Vector4(12, 8, 12, 8) if v == "Tab" else (Vector4(14, 8, 14, 8) if v == "MenuItem" else Vector4(18, 10, 18, 10)))))
		var rad = 14 if v == "Tile" else (8 if v in ["Small", "Row", "Tab", "MenuItem"] else 10)
		var normal = _sb(bgc, brd, 1 if brd.a > 0 else 0, rad, pad)
		var hover = _sb(bgc.lightened(0.08) if v != "Tab" and v != "MenuItem" else bgc, TEAL if v not in ["Primary", "Gold", "Tab", "MenuItem"] else Color(1, 1, 1, 0.9), 2 if v not in ["Tab", "MenuItem"] else 0, rad, pad)
		if v == "Row" or v == "Tile": hover.bg_color = Color(0.25, 0.88, 0.77, 0.1) if v == "Row" else Color(0.16, 0.23, 0.28, 0.95)
		if v == "Primary" or v == "Gold": hover.shadow_color = Color(1, 1, 1, 0.35); hover.shadow_size = 8
		if v == "Tile": hover.shadow_color = Color(0.25, 0.88, 0.77, 0.25); hover.shadow_size = 14
		var dis = normal.duplicate(); dis.bg_color.a *= 0.4
		theme.set_stylebox("normal", v, normal); theme.set_stylebox("hover", v, hover); theme.set_stylebox("focus", v, hover)
		theme.set_stylebox("pressed", v, hover); theme.set_stylebox("disabled", v, dis); theme.set_stylebox("hover_pressed", v, hover)
		for k in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			theme.set_color(k, v, fc if k == "font_color" else (Color.WHITE if v in ["Tab", "MenuItem"] else fc))
		theme.set_color("font_disabled_color", v, Color(fc, 0.35))
		theme.set_font("font", v, font_bold if v not in ["MenuItem"] else font_head)
		theme.set_font_size("font_size", v, 13 if v == "Small" else (18 if v == "Tab" else (17 if v == "MenuItem" else 15)))
	# inputs
	for t in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", t, _sb(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.16), 1, 8, Vector4(10, 7, 10, 7)))
		theme.set_stylebox("focus", t, _sb(Color(0, 0, 0, 0.45), TEAL, 2, 8, Vector4(10, 7, 10, 7)))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_stylebox("normal", "OptionButton", _sb(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.16), 1, 8, Vector4(10, 7, 30, 7)))
	theme.set_stylebox("hover", "OptionButton", _sb(Color(0, 0, 0, 0.45), TEAL, 2, 8, Vector4(10, 7, 30, 7)))
	theme.set_stylebox("focus", "OptionButton", _sb(Color(0, 0, 0, 0.45), TEAL, 2, 8, Vector4(10, 7, 30, 7)))
	theme.set_stylebox("pressed", "OptionButton", _sb(Color(0, 0, 0, 0.45), TEAL, 2, 8, Vector4(10, 7, 30, 7)))
	theme.set_stylebox("panel", "PopupMenu", _sb(Color("#141c26"), Color(1, 1, 1, 0.15), 1, 8, Vector4(6, 6, 6, 6)))
	theme.set_stylebox("hover", "PopupMenu", _sb(Color(0.25, 0.88, 0.77, 0.25), Color(0, 0, 0, 0), 0, 6, Vector4(6, 4, 6, 4)))
	theme.set_stylebox("panel", "PanelContainer", _sb(PANEL, Color(1, 1, 1, 0.09), 1, 16, Vector4(18, 16, 18, 16)))
	theme.set_type_variation("Glass", "PanelContainer")
	theme.set_stylebox("panel", "Glass", _sb(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.09), 1, 12, Vector4(12, 10, 12, 10)))
	var bar_bg = _sb(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 6, Vector4(0, 0, 0, 0)); var bar_fg = _sb(TEAL, Color(0, 0, 0, 0), 0, 6, Vector4(0, 0, 0, 0))
	theme.set_stylebox("background", "ProgressBar", bar_bg); theme.set_stylebox("fill", "ProgressBar", bar_fg)
	theme.set_type_variation("GoldBar", "ProgressBar"); theme.set_stylebox("fill", "GoldBar", _sb(GOLD2, Color(0, 0, 0, 0), 0, 6, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("slider", "HSlider", _sb(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 0, 4, Vector4(0, 3, 0, 3)))
	theme.set_stylebox("grabber_area", "HSlider", _sb(TEAL, Color(0, 0, 0, 0), 0, 4, Vector4(0, 3, 0, 3)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _sb(TEAL, Color(0, 0, 0, 0), 0, 4, Vector4(0, 3, 0, 3)))
	theme.set_stylebox("focus", "HSlider", _sb(Color(0, 0, 0, 0), TEAL, 2, 6, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("focus", "CheckBox", _sb(Color(0, 0, 0, 0), TEAL, 2, 6, Vector4(4, 2, 4, 2)))
	theme.set_color("font_color", "CheckBox", TEXT); theme.set_color("font_focus_color", "CheckBox", Color.WHITE); theme.set_color("font_hover_color", "CheckBox", Color.WHITE)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	theme.set_constant("separation", "VBoxContainer", 10); theme.set_constant("separation", "HBoxContainer", 10)

func _input_map() -> void:
	var add = func(action: String, events: Array):
		if not InputMap.has_action(action): InputMap.add_action(action)
		for e in events: InputMap.action_add_event(action, e)
	var k = func(code): var e = InputEventKey.new(); e.physical_keycode = code; return e
	var j = func(btn): var e = InputEventJoypadButton.new(); e.button_index = btn; return e
	add.call("tab_prev", [k.call(KEY_Q), j.call(JOY_BUTTON_LEFT_SHOULDER)])
	add.call("tab_next", [k.call(KEY_E), j.call(JOY_BUTTON_RIGHT_SHOULDER)])
	InputMap.action_add_event("ui_cancel", k.call(KEY_BACKSPACE))

# ------------------------------------------------------------------ router
func go(name: String, params := {}, push := true) -> void:
	if cur and push and cur_name != "": stack.append([cur_name, cur_params, _focus_path()])
	_show(name, params)

## replacing the same screen (e.g. after claiming a reward) keeps the controller focus where it was
func replace(name: String, params := {}) -> void:
	if name == cur_name: _restore = _focus_path()
	_show(name, params)
func reset(name: String, params := {}) -> void: stack.clear(); _show(name, params)
func back() -> void:
	if stack.is_empty(): return
	var p = stack.pop_back()
	if p.size() > 2: _restore = p[2]
	_show(p[0], p[1])
func rerender() -> void: _show(cur_name, cur_params)

func apply_display() -> void:
	var s: Dictionary = Save.data.settings if Save.data else Save.default_settings()
	Engine.max_fps = int(s.get("fps_cap", 60))
	var vs = DisplayServer.VSYNC_ENABLED if s.get("vsync", true) else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != vs: DisplayServer.window_set_vsync_mode(vs)

func _show(name: String, params: Dictionary) -> void:
	apply_display()
	var mod = null
	for m in modules: if m.has_method("s_" + name): mod = m; break
	if mod == null: push_error("No screen " + name); return
	currency_labels = currency_labels.filter(func(l): return is_instance_valid(l))
	if cur and is_instance_valid(cur):
		var old = cur
		var tw = create_tween(); tw.tween_property(old, "modulate:a", 0.0, 0.15); tw.tween_callback(old.queue_free)
	cur_name = name; cur_params = params; cur_tab = ""
	cur_back = Callable(); _segs = []
	var info: Dictionary = mod.call("s_" + name, params)
	cur = info.node
	cur_back = info.get("back", Callable(self, "back"))
	cur_tab = info.get("tab", "")
	bg.set_mode(info.get("bg", "hub"))
	cur.set_anchors_preset(Control.PRESET_FULL_RECT)
	cur.modulate.a = 0.0; cur.position.x = 24
	host.add_child(cur)
	var tw2 = create_tween().set_parallel(); tw2.tween_property(cur, "modulate:a", 1.0, 0.3); tw2.tween_property(cur, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not info.get("no_music", false) and not in_match: Sfx.music_on()
	var restore = _restore; _restore = []
	await get_tree().process_frame
	if not is_instance_valid(cur): return
	# put controller focus back where it was; if that exact control is gone, use the nearest surviving section
	var path: Array = restore.duplicate()
	while not path.is_empty():
		var n = _resolve_path(path)
		if n is Control and n.is_visible_in_tree():
			if n.focus_mode == Control.FOCUS_ALL: n.grab_focus(); return
			var f = _find_focusable(n)
			if f and path.size() >= 4: f.grab_focus(); return
		path.pop_back()
	focus_first(cur)

func focus_first(node: Node) -> void:
	var pref = _find_auto(node)
	if pref: pref.grab_focus(); return
	var f = _find_focusable(node)
	if f: f.grab_focus()
func _find_auto(n: Node) -> Control:
	if n is Control and n.has_meta("autofocus") and n.is_visible_in_tree() and n.focus_mode != Control.FOCUS_NONE: return n
	for c in n.get_children():
		var r = _find_auto(c)
		if r: return r
	return null
func _find_focusable(n: Node) -> Control:
	if n is Control and n.focus_mode == Control.FOCUS_ALL and n.is_visible_in_tree() and not (n is BaseButton and n.disabled): return n
	for c in n.get_children():
		var r = _find_focusable(c)
		if r: return r
	return null

func _unhandled_input(event: InputEvent) -> void:
	if in_match: return
	if event.is_action_pressed("ui_cancel"):
		var fo = get_viewport().gui_get_focus_owner()
		if fo is LineEdit and event is InputEventKey and event.physical_keycode == KEY_BACKSPACE: return
		get_viewport().set_input_as_handled()
		if not modals.is_empty(): modals[-1].cancel.call(); return
		Sfx.play("back")
		if cur_back.is_valid(): cur_back.call()
	elif modals.is_empty() and cur_tab != "" and (event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next")):
		var fo = get_viewport().gui_get_focus_owner()
		if fo is LineEdit: return
		var i = HUB_TABS.map(func(t): return t[0]).find(cur_tab)
		var d = -1 if event.is_action_pressed("tab_prev") else 1
		Sfx.play("tab"); replace(HUB_TABS[(i + d + HUB_TABS.size()) % HUB_TABS.size()][0])

# ------------------------------------------------------------------ controller driver
## Smooth controller menus: hold-to-repeat navigation with acceleration, right stick scrolling,
## L2/R2 to switch sub-tabs, smooth scroll-to-focus, and the mouse can't steal focus while you use a pad.
var _restore = []
var _segs = []
var _nav = {"dir": Vector2i.ZERO, "t": 0.0, "rep": 0}
var _trig = {"l": false, "r": false}
var _scroll_acc = Vector2.ZERO
var _last_mouse = -10.0

func mouse_recent() -> bool:
	if Cloud.companion(): return false     # touch screens have no hover: never select what the finger passes over
	return Time.get_ticks_msec() / 1000.0 - _last_mouse < 0.6

## TOUCH SCROLLING (companion): once a finger moves past a few pixels it becomes a scroll of the
## list under it in that direction (sideways strips or the page), and the tap is cancelled.
var _tp = {"down": false, "drag": false, "pos": Vector2.ZERO, "sc": null, "axis": 1, "anchor": Vector2.ZERO, "start": 0.0, "samples": [], "vel": 0.0, "msc": null}
const DRAG_START := 7.0
## finger follows the content 1:1 (absolute mapping from where the drag began), then a momentum fling with friction
func _touch_scroll(event: InputEvent) -> bool:
	if in_match or not Cloud.companion(): return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x < -9000: return false
			var was_flinging: bool = abs(_tp.vel) > 60.0
			_tp.vel = 0.0; _tp.msc = null      # a touch stops any fling
			_tp.down = true; _tp.drag = false; _tp.pos = event.position; _tp.sc = null; _tp.samples = [[_now(), event.position]]
			if was_flinging: get_viewport().set_input_as_handled(); _tp.catch = true; return true   # catching a fling isn't a tap
			_tp.catch = false
			# double-tap to open: the first tap only selects (highlights) a button, a second tap on it opens it
			if _double_tap_on():
				var b = _button_at(event.position)
				if is_instance_valid(_last_ring) and (b == null or b != _armed.get("b")): _last_ring.queue_free()
				if b != null and (b != _armed.get("b") or _now() - float(_armed.get("t", 0.0)) > 3.0):
					_armed = {"b": b, "t": _now()}
					_flash_armed(b)
					get_viewport().set_input_as_handled(); _tp.catch = true; return true
				_armed = {}
			return false
		var was: bool = _tp.drag or _tp.get("catch", false)
		_tp.down = false
		if _tp.drag:
			_tp.drag = false
			_tp.vel = _release_velocity()
			if dbg: print("RELEASE v=", _sc_get(_tp.sc, _tp.axis), " vel=", _tp.vel)
			if is_instance_valid(_tp.sc) and abs(_tp.vel) > 120.0: _tp.msc = _tp.sc
		if was:
			_tp.catch = false
			# let the release through at a far-away point so the pressed button sees "released outside"
			var up = event.duplicate(); up.position = Vector2(-9999, -9999); up.global_position = up.position
			get_viewport().set_input_as_handled(); Input.parse_input_event(up)
			return true
		return false
	# real finger positions come from ScreenDrag; the browser's emulated mouse can lag or jump back to where the touch began,
	# so while a finger is down the mouse motion is only swallowed, never used for the scroll position
	if dbg and (event is InputEventScreenTouch or event is InputEventMouseButton): print("EV ", event.get_class(), " pressed=", event.pressed, " pos=", event.position, " down=", _tp.down)
	# iPhones number every new touch (1, 2, 3…), so follow whichever finger came down first rather than index 0
	if event is InputEventScreenTouch and (not _touching or event.index == _touch_id):
		_touching = event.pressed; _touch_id = event.index
		if event.pressed:
			_tp.samples = [[_now(), event.position]]; _tp.pos = event.position
			if not _tp.down: _tp.down = true; _tp.drag = false; _tp.sc = null
		elif _tp.down:
			# no emulated mouse release came first: finish the gesture here
			_tp.down = false
			if _tp.drag:
				_tp.drag = false; _tp.vel = _release_velocity()
				if is_instance_valid(_tp.sc) and abs(_tp.vel) > 120.0: _tp.msc = _tp.sc
				get_viewport().set_input_as_handled(); return true
		if _tp.drag or _tp.get("catch", false): get_viewport().set_input_as_handled(); return true
		return false
	if event is InputEventScreenDrag:
		if event.index == _touch_id and _tp.down: _drag_to(event.position)
		get_viewport().set_input_as_handled(); return true
	if event is InputEventMouseMotion and _tp.down:
		if event.position.x < -9000: return false
		if _touching:
			if _tp.drag: get_viewport().set_input_as_handled(); return true
			return false
		_drag_to(event.position)
		if _tp.drag: get_viewport().set_input_as_handled(); return true
		return false
	return false

var _touching = false
var _touch_id = 0
var dbg = false
func _drag_to(pos: Vector2) -> void:
	# ignore teleports (a stale event far from the finger's last point)
	if not _tp.samples.is_empty() and pos.distance_to(_tp.samples[-1][1]) > 160.0: return
	var d: Vector2 = pos - _tp.pos
	_tp.samples.append([_now(), pos])
	while _tp.samples.size() > 2 and _now() - _tp.samples[0][0] > 0.1: _tp.samples.pop_front()
	if not _tp.drag:
		if d.length() < DRAG_START: return
		_tp.drag = true
		# thumbs move in arcs: only go sideways when the swipe is clearly horizontal
		_tp.axis = 0 if abs(d.x) > abs(d.y) * 1.6 else 1
		_tp.sc = _scroll_under(_tp.pos, _tp.axis)
		if _tp.sc == null: _tp.axis = 1 - _tp.axis; _tp.sc = _scroll_under(_tp.pos, _tp.axis)
		_tp.anchor = pos
		_tp.start = _sc_get(_tp.sc, _tp.axis)
		if dbg: print("DRAGSTART sc=", _tp.sc, " path=", _tp.sc.get_path() if _tp.sc else "", " start=", _tp.start, " pos=", pos)
		# a drag never "arms" a button for double-tap, and the "mouse" moves off the button so it won't fire on release
		if is_instance_valid(_last_ring): _last_ring.queue_free()
		_armed = {}
		var mv = InputEventMouseMotion.new(); mv.position = Vector2(-9999, -9999); mv.global_position = mv.position; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
	if is_instance_valid(_tp.sc):
		var off: float = (pos - _tp.anchor).x if _tp.axis == 0 else (pos - _tp.anchor).y
		var want: float = _tp.start - off
		_sc_set(_tp.sc, _tp.axis, want)
		# hit an end: re-anchor so reversing direction responds at once
		var got: float = _sc_get(_tp.sc, _tp.axis)
		if abs(got - want) > 0.5: _tp.start = got; _tp.anchor = pos

func _now() -> float: return Time.get_ticks_usec() / 1000000.0

var _armed = {}
func _double_tap_on() -> bool:
	return Save.data != null and Save.data.settings.get("double_tap", true) and modals.is_empty() and is_instance_valid(cur)
## the button a tap at p would press: topmost visible, enabled button in the current screen, not clipped by a scroll area
func _button_at(p: Vector2) -> BaseButton:
	var best: BaseButton = null
	for n in cur.find_children("*", "BaseButton", true, false):
		var b: BaseButton = n
		if b.disabled or b.mouse_filter == Control.MOUSE_FILTER_IGNORE or not b.is_visible_in_tree() or not b.get_global_rect().has_point(p): continue
		var clipped = false
		var a = b.get_parent()
		while a != null and a != cur:
			if a is ScrollContainer and not a.get_global_rect().has_point(p): clipped = true; break
			a = a.get_parent()
		if not clipped: best = b    # later in the tree = drawn on top
	return best
## a quick pulse so it's obvious the button is selected and waiting for the second tap
func _flash_armed(b: BaseButton) -> void:
	Sfx.play("move")
	var ring = Panel.new(); ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", _sb(Color(0.25, 0.88, 0.77, 0.1), TEAL, 2, 10, Vector4.ZERO))
	ring.size = b.size; ring.position = Vector2.ZERO; b.add_child(ring)
	var tw = ring.create_tween(); tw.tween_interval(2.6); tw.tween_property(ring, "modulate:a", 0.0, 0.3); tw.tween_callback(ring.queue_free)
	if not _hinted:
		_hinted = true; toast("Tap again to open", "info")
	_last_ring = ring
var _hinted = false
var _last_ring: Control = null
func _sc_get(sc, axis: int) -> float:
	if not is_instance_valid(sc): return 0.0
	var bar = sc.get_h_scroll_bar() if axis == 0 else sc.get_v_scroll_bar()
	return bar.value
func _sc_set(sc, axis: int, v: float) -> void:
	# set the bar's float value: sub-pixel precise (scroll_vertical only takes whole pixels)
	var bar = sc.get_h_scroll_bar() if axis == 0 else sc.get_v_scroll_bar()
	bar.value = clamp(v, 0.0, max(0.0, bar.max_value - bar.page))
## pixels/second over the last ~100 ms (0 if the finger paused before lifting)
func _release_velocity() -> float:
	var sm: Array = _tp.samples
	if sm.size() < 2 or _now() - sm[-1][0] > 0.08: return 0.0
	var a = sm[0]; var b = sm[-1]; var dt: float = max(0.008, b[0] - a[0])
	var dv: Vector2 = (b[1] - a[1]) / dt
	return clamp(-(dv.x if _tp.axis == 0 else dv.y), -5000.0, 5000.0)
func _fling_step(delta: float) -> void:
	if not is_instance_valid(_tp.msc) or abs(_tp.vel) < 15.0 or _tp.down: _tp.msc = null; return
	var before: float = _sc_get(_tp.msc, _tp.axis)
	_sc_set(_tp.msc, _tp.axis, before + _tp.vel * delta)
	if abs(_sc_get(_tp.msc, _tp.axis) - before) < 0.01 and abs(_tp.vel * delta) > 0.5: _tp.vel = 0.0; return   # hit the end
	_tp.vel *= exp(-3.2 * delta)    # friction

## deepest visible ScrollContainer under the point that can scroll on that axis (0 = sideways, 1 = up/down)
func _scroll_under(p: Vector2, axis: int) -> ScrollContainer:
	var best: ScrollContainer = null
	var roots = [cur] if modals.is_empty() else [modals[-1].node]
	for r in roots:
		if not is_instance_valid(r): continue
		for n in r.find_children("*", "ScrollContainer", true, false):
			var sc: ScrollContainer = n
			if not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(p): continue
			var mode = sc.horizontal_scroll_mode if axis == 0 else sc.vertical_scroll_mode
			if mode == ScrollContainer.SCROLL_MODE_DISABLED: continue
			var bar = sc.get_h_scroll_bar() if axis == 0 else sc.get_v_scroll_bar()
			if bar.max_value - bar.page <= 1: continue
			if best == null or best.is_ancestor_of(sc): best = sc
	return best

func _input(event: InputEvent) -> void:
	if _touch_scroll(event): return
	if event is InputEventMouseMotion and event.relative.length() > 1.5:
		_last_mouse = Time.get_ticks_msec() / 1000.0
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		_last_mouse = Time.get_ticks_msec() / 1000.0
	elif (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
		_last_mouse = -10.0
		if not in_match and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _strip_pad_nav() -> void:
	for a in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion: InputMap.action_erase_event(a, e)

func _process(delta: float) -> void:
	if _tp.msc != null: _fling_step(delta)
	if in_match:
		_nav.dir = Vector2i.ZERO; return
	var dir = Vector2i.ZERO; var rs = Vector2.ZERO; var lt = false; var rt = false
	for d in Input.get_connected_joypads():
		var v = Vector2i.ZERO
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP): v.y = -1
		elif Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN): v.y = 1
		elif Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT): v.x = -1
		elif Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT): v.x = 1
		else:
			var ls = Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
			# hysteresis: a held stick stays engaged until it drops well below the press threshold
			var th = 0.38 if _nav.dir != Vector2i.ZERO else 0.6
			if ls.length() > th:
				if abs(ls.x) > abs(ls.y) * 1.15: v.x = 1 if ls.x > 0 else -1
				elif abs(ls.y) > abs(ls.x) * 1.15: v.y = 1 if ls.y > 0 else -1
				else: v = _nav.dir   # diagonal: keep the current direction instead of flickering
		if v != Vector2i.ZERO: dir = v
		var r = Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
		if r.length() > 0.22: rs = r
		if Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.6: lt = true
		if Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.6: rt = true
	if dir != _nav.dir:
		_nav.dir = dir; _nav.t = 0.0; _nav.rep = 0
		if dir != Vector2i.ZERO: _send_nav(dir)
	elif dir != Vector2i.ZERO:
		_nav.t += delta
		var wait: float = 0.34 if _nav.rep == 0 else max(0.05, 0.1 - _nav.rep * 0.006)
		if _nav.t >= wait: _nav.t = 0.0; _nav.rep += 1; _send_nav(dir)
	if rs != Vector2.ZERO: _scroll_by(rs * rs.length() * delta * 1400.0)
	if lt and not _trig.l: _cycle_seg(-1)
	if rt and not _trig.r: _cycle_seg(1)
	_trig.l = lt; _trig.r = rt

func _send_nav(d: Vector2i) -> void:
	var a = "ui_up" if d.y < 0 else ("ui_down" if d.y > 0 else ("ui_left" if d.x < 0 else "ui_right"))
	var fo = get_viewport().gui_get_focus_owner()
	if fo == null:
		var scope = modals[-1].node if not modals.is_empty() else cur
		if scope: focus_first(scope)
		return
	var e = InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 = InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)

func _scroll_target() -> ScrollContainer:
	var fo = get_viewport().gui_get_focus_owner()
	var n: Node = fo
	while n != null:
		if n is ScrollContainer and (n.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or n.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED): return n
		n = n.get_parent()
	return _first_scroll(modals[-1].node if not modals.is_empty() else cur)
func _first_scroll(n: Node) -> ScrollContainer:
	if n == null: return null
	if n is ScrollContainer and n.is_visible_in_tree(): return n
	for c in n.get_children():
		var r = _first_scroll(c)
		if r: return r
	return null

func _scroll_by(v: Vector2) -> void:
	var sc = _scroll_target()
	if sc == null: return
	_scroll_acc += v
	var ix = int(_scroll_acc.x); var iy = int(_scroll_acc.y)
	_scroll_acc -= Vector2(ix, iy)
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: sc.scroll_horizontal += ix
	sc.scroll_vertical += iy

func _cycle_seg(d: int) -> void:
	if not modals.is_empty() or _segs.is_empty(): return
	var fo = get_viewport().gui_get_focus_owner()
	if fo is LineEdit: return
	var s: Dictionary = _segs[0]
	var keys: Array = s.items.map(func(x): return str(x[0]))
	var i = keys.find(str(s.current))
	Sfx.play("tab")
	s.cb.call(s.items[(i + d + keys.size()) % keys.size()][0])

## glide the nearest scroll container so the newly focused control is fully visible
func _on_focus_changed(c: Control) -> void:
	if in_match or c == null or Cloud.companion(): return   # on phones the finger scrolls, not the focus
	var n: Node = c.get_parent()
	while n != null and not (n is ScrollContainer): n = n.get_parent()
	if n == null: return
	var sc: ScrollContainer = n
	var r = c.get_global_rect(); var v = sc.get_global_rect()
	var m = 28.0
	var ty: int = sc.scroll_vertical; var tx: int = sc.scroll_horizontal
	if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		if r.position.y < v.position.y + m: ty += int(r.position.y - v.position.y - m)
		elif r.end.y > v.end.y - m: ty += int(min(r.end.y - (v.end.y - m), r.position.y - v.position.y - m))
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		if r.position.x < v.position.x + m: tx += int(r.position.x - v.position.x - m)
		elif r.end.x > v.end.x - m: tx += int(min(r.end.x - (v.end.x - m), r.position.x - v.position.x - m))
	ty = max(0, ty); tx = max(0, tx)
	if ty == sc.scroll_vertical and tx == sc.scroll_horizontal: return
	if sc.has_meta("tw"):
		var old = sc.get_meta("tw")
		if old is Tween and old.is_valid(): old.kill()
	var tw = sc.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sc, "scroll_vertical", ty, 0.18); tw.tween_property(sc, "scroll_horizontal", tx, 0.18)
	sc.set_meta("tw", tw)

func _focus_path() -> Array:
	var fo = get_viewport().gui_get_focus_owner()
	if cur == null or not is_instance_valid(cur) or fo == null or not cur.is_ancestor_of(fo): return []
	var path = []
	var n: Node = fo
	while n != cur:
		path.push_front(n.get_index()); n = n.get_parent()
	return path
func _resolve_path(path: Array) -> Node:
	var n: Node = cur
	for i in path:
		if n == null or i >= n.get_child_count(): return null
		n = n.get_child(i)
	return n

# ------------------------------------------------------------------ widgets
func label(text: String, size := 15, color := TEXT, font: Font = null) -> Label:
	var l = Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if font: l.add_theme_font_override("font", font)
	return l
func head(text: String, size := 40, color := TEXT) -> Label: return label(text, size, color, font_head)
func bold(text: String, size := 15, color := TEXT) -> Label: return label(text, size, color, font_bold)
func caps(text: String, size := 12, color := DIM) -> Label: return label(text.to_upper(), size, color, font_bold)
func wrapl(l: Label, w := 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if w > 0: l.custom_minimum_size.x = w
	return l

func btn(text: String, cb: Callable, variant := "", autofocus := false) -> Button:
	var b = Button.new(); b.text = text.replace("Ⓐ", Pad.glyph("A")) if Pad.style == "ps" else text
	if variant != "": b.theme_type_variation = variant
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	b.mouse_entered.connect(func(): if mouse_recent() and not b.disabled and not b.has_focus(): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("move"))
	if autofocus: b.set_meta("autofocus", true)
	return b

func vb(sep := 10, children := []) -> VBoxContainer:
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", sep)
	for c in children: v.add_child(c)
	return v
func hb(sep := 10, children := []) -> HBoxContainer:
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", sep)
	for c in children: h.add_child(c)
	return h
func grow(c: Control, v := true, h := true) -> Control:
	if v: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if h: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
func spacer() -> Control: var c = Control.new(); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return c
func vspacer() -> Control: var c = Control.new(); c.size_flags_vertical = Control.SIZE_EXPAND_FILL; return c
func panel(child: Control, variant := "") -> PanelContainer:
	var p = PanelContainer.new()
	if variant != "": p.theme_type_variation = variant
	p.add_child(child); return p
func scroll(child: Control, horizontal := false) -> ScrollContainer:
	var s = ScrollContainer.new(); s.size_flags_vertical = Control.SIZE_EXPAND_FILL; s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = false   # we scroll smoothly to the focused control ourselves
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child); return s
func bar(value: float, max_v: float, variant := "") -> ProgressBar:
	var b = ProgressBar.new(); b.max_value = max(1.0, max_v); b.value = value; b.show_percentage = false; b.custom_minimum_size = Vector2(0, 8)
	if variant != "": b.theme_type_variation = variant
	return b
func option(items: Array, selected, cb: Callable) -> OptionButton:
	## items: [[value, label], ...]
	var o = OptionButton.new(); o.focus_mode = Control.FOCUS_ALL
	for i in items.size():
		o.add_item(str(items[i][1]), i); o.set_item_metadata(i, items[i][0])
		if str(items[i][0]) == str(selected): o.select(i)
	o.item_selected.connect(func(i): Sfx.play("select"); cb.call(o.get_item_metadata(i)))
	o.mouse_entered.connect(func(): if mouse_recent() and not o.has_focus(): o.grab_focus())
	return o
func field(caption: String, ctl: Control) -> VBoxContainer:
	return vb(4, [caps(caption, 11), ctl])
func line(text: String, cb: Callable, placeholder := "", w := 200.0) -> LineEdit:
	var l = LineEdit.new(); l.text = text; l.placeholder_text = placeholder; l.custom_minimum_size.x = w
	l.text_changed.connect(cb); return l
func icon(kind: String, arg, s: Vector2) -> Icon: return Icon.make(kind, arg, s)
func card(p: Dictionary, cs := 10.0, mini := false, on_press = null) -> PlayerCard:
	var c = PlayerCard.make(p, cs, mini)
	if on_press is Callable: c.pressed.connect(func(): Sfx.play("select"); on_press.call())
	return c
func tile(children: Array, cb: Callable, min_size := Vector2.ZERO, autofocus := false) -> Button:
	var b = Button.new(); b.theme_type_variation = "Tile"; b.focus_mode = Control.FOCUS_ALL; b.custom_minimum_size = min_size
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	b.mouse_entered.connect(func(): if mouse_recent() and not b.has_focus(): b.grab_focus())
	b.focus_entered.connect(func():
		Sfx.play("move"); b.pivot_offset = b.size / 2
		b.create_tween().tween_property(b, "scale", Vector2(1.025, 1.025), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	b.focus_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	var m = MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + s, 20)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = vb(6, children); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v); b.add_child(m)
	_ignore_mouse(v)
	# Buttons don't size to their children: keep the tile at least as big as its content
	var fit = func(): b.custom_minimum_size = Vector2(max(min_size.x, m.get_combined_minimum_size().x), max(min_size.y, m.get_combined_minimum_size().y))
	m.minimum_size_changed.connect(fit)
	fit.call_deferred()
	if autofocus: b.set_meta("autofocus", true)
	return b
func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control: c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.focus_mode = Control.FOCUS_NONE
		_ignore_mouse(c)
func pill(text: String, color := TEXT, bgc := Color(1, 1, 1, 0.08)) -> PanelContainer:
	var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", _sb(bgc, Color(0, 0, 0, 0), 0, 99, Vector4(10, 3, 10, 3)))
	p.add_child(bold(text, 12, color)); return p
func seg(items: Array, current: String, cb: Callable) -> HBoxContainer:
	_segs.append({"items": items, "current": current, "cb": cb})
	var h = hb(2)
	var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.09), 1, 10, Vector4(3, 3, 3, 3)))
	var inner = hb(2); p.add_child(inner)
	for it in items:
		var b = btn(it[1], func(): cb.call(it[0]), "Small")
		if it[0] == current:
			b.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0.16), Color(0, 0, 0, 0), 0, 8, Vector4(12, 6, 12, 6)))
		inner.add_child(b)
	if mobile:
		# phones: a sideways-swipe strip on its own line instead of a wrapped column
		var sc = ScrollContainer.new(); sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		sc.follow_focus = false; sc.custom_minimum_size = Vector2(root.size.x - 60, 46); sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(p); h.add_child(sc); return h
	h.add_child(p); return h
func coin_text(n) -> String: return "● " + Sys.fmt(n)

## animated currency icons: a faceted Prime Points gem with a twinkle, a minted gold coin, an XP ring
class CurIcon extends Control:
	var kind = "points"; var t = 0.0; var acc = 0.0; var prog = 0.0
	func _ready() -> void: t = randf() * 6.0
	func _process(d: float) -> void:
		t += d; acc += d
		if acc > 1.0 / 15.0 and is_visible_in_tree(): acc = 0.0; queue_redraw()
	func _draw() -> void:
		var c = size / 2; var r = min(size.x, size.y) * 0.5
		match kind:
			"points": UI.paint_gem(self, c, r, t)
			"coins": UI.paint_coin(self, c, r, t)
			_:
				draw_arc(c, r * 0.86, 0, TAU, 32, Color(1, 1, 1, 0.15), r * 0.18)
				draw_arc(c, r * 0.86, -PI / 2, -PI / 2 + TAU * clamp(prog, 0.0, 1.0), 32, Color("#3fe0c8"), r * 0.18)
				draw_circle(c, r * 0.62, Color("#1a2230"))
				var st = PackedVector2Array()
				for i in 10:
					var an = -PI / 2 + i * TAU / 10.0; var rr = r * (0.42 if i % 2 == 0 else 0.18)
					st.append(c + Vector2(cos(an), sin(an)) * rr)
				draw_colored_polygon(st, Color("#ffd86b"))

## brilliant-cut gem: crown + table + pavilion facets in teal→violet, rim light and a twinkling star
static func paint_gem(ci: CanvasItem, c: Vector2, r: float, t := 0.0) -> void:
	var w = r * 0.98; var top = c.y - r * 0.62; var gird = c.y - r * 0.12; var tip = c.y + r * 0.92
	var tl = Vector2(c.x - w * 0.52, top); var tr = Vector2(c.x + w * 0.52, top)
	var gl = Vector2(c.x - w, gird); var gr = Vector2(c.x + w, gird); var bt = Vector2(c.x, tip)
	var ml = Vector2(c.x - w * 0.18, gird); var mr = Vector2(c.x + w * 0.18, gird)
	for k in 4: ci.draw_circle(c, r * (1.25 - k * 0.12), Color(0.37, 0.95, 0.88, 0.05 + 0.02 * k * (0.7 + 0.3 * sin(t * 1.7))))
	ci.draw_colored_polygon(PackedVector2Array([gl + Vector2(0, r * 0.1), Vector2(c.x, tip + r * 0.1), gr + Vector2(0, r * 0.1)]), Color(0, 0, 0, 0.3))
	# pavilion (lower) facets
	ci.draw_colored_polygon(PackedVector2Array([gl, ml, bt]), Color("#1aa6a0"))
	ci.draw_colored_polygon(PackedVector2Array([ml, mr, bt]), Color("#5ff2e0"))
	ci.draw_colored_polygon(PackedVector2Array([mr, gr, bt]), Color("#7a4fd6"))
	# crown (upper) facets
	ci.draw_colored_polygon(PackedVector2Array([gl, tl, ml]), Color("#3ee6d2"))
	ci.draw_colored_polygon(PackedVector2Array([tl, tr, mr, ml]), Color("#b8fff6"))
	ci.draw_colored_polygon(PackedVector2Array([tr, gr, mr]), Color("#9a7bff"))
	var o = PackedVector2Array([tl, tr, gr, bt, gl, tl])
	ci.draw_polyline(o, Color(1, 1, 1, 0.85), max(1.0, r * 0.08), true)
	ci.draw_line(gl, gr, Color(1, 1, 1, 0.55), max(1.0, r * 0.05))
	# moving shine + twinkle
	var sh = fmod(t * 0.35, 1.6)
	if sh < 1.0:
		var x = lerpf(tl.x, tr.x, sh)
		ci.draw_line(Vector2(x, top + r * 0.04), Vector2(x - r * 0.25, gird - r * 0.04), Color(1, 1, 1, 0.7), max(1.0, r * 0.1))
	var tw = max(0.0, sin(t * 2.3)) 
	if tw > 0.05:
		var sp = Vector2(c.x + w * 0.55, top - r * 0.08); var s = r * 0.42 * tw
		ci.draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(1, 1, 1, tw), max(1.0, r * 0.07))
		ci.draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(1, 1, 1, tw), max(1.0, r * 0.07))

## minted coin: rim gradient, reeded edge, embossed "PF", sweeping shine
static func paint_coin(ci: CanvasItem, c: Vector2, r: float, t := 0.0) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.12), r * 0.98, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r * 0.98, Color("#9a6a12"))
	for i in 5: ci.draw_circle(c - Vector2(0, r * 0.03 * i), r * (0.94 - i * 0.02), Color("#f8d77a").lerp(Color("#d4a12a"), i / 4.0))
	for i in 24:
		var a = TAU * i / 24.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.8, c + Vector2(cos(a), sin(a)) * r * 0.9, Color("#b8861d"), max(1.0, r * 0.06))
	ci.draw_circle(c, r * 0.68, Color("#e9b93e"))
	ci.draw_arc(c, r * 0.68, 0, TAU, 28, Color("#fff1c4"), max(1.0, r * 0.07))
	if r >= 9: Gfx.text_c(ci, UI.font_head, c.x, c.y + r * 0.3, "PF", int(r * 0.85), Color("#8a5a10"))
	else: ci.draw_circle(c, r * 0.28, Color("#b8861d"))
	var sh = fmod(t * 0.3, 1.8)
	if sh < 1.0:
		var x = c.x - r * 0.35 + sh * r * 0.8
		ci.draw_line(Vector2(x + r * 0.15, c.y - r * 0.5), Vector2(x - r * 0.15, c.y + r * 0.5), Color(1, 1, 1, 0.5), max(1.0, r * 0.1))

func _cur_pill(icon: Control, lab: Label, tint: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.03, 0.05, 0.08, 0.72); sb.border_color = Color(tint, 0.45); sb.set_border_width_all(1); sb.set_corner_radius_all(18)
	sb.content_margin_left = 6; sb.content_margin_right = 14; sb.content_margin_top = 3; sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(hb(8, [icon, lab]))
	return pc

func currency_bar() -> HBoxContainer:
	var h = hb(10)
	var c = bold(Sys.fmt(Sys.D().coins), 16, Color("#ffd86b")); c.set_meta("cur", "coins")
	var p = bold(Sys.fmt(Sys.D().points), 16, Color("#8ff5ea")); p.set_meta("cur", "points")
	var lv = bold("LVL %d" % Sys.D().profile.level, 14, TEXT); lv.set_meta("cur", "level")
	var lvi = CurIcon.new(); lvi.kind = "level"; lvi.custom_minimum_size = Vector2(24, 24)
	lvi.prog = float(Sys.D().profile.xp) / max(1, Sys.xp_need(Sys.D().profile.level))
	h.add_child(_cur_pill(_coin_icon(), c, Color("#ffd86b")))
	h.add_child(_cur_pill(_pts_icon(), p, Color("#5ff2e0")))
	if not mobile: h.add_child(_cur_pill(lvi, lv, Color(1, 1, 1)))
	currency_labels.append_array([c, p, lv])
	return h
func _coin_icon() -> Control:
	var i = CurIcon.new(); i.kind = "coins"; i.custom_minimum_size = Vector2(24, 24); i.mouse_filter = Control.MOUSE_FILTER_IGNORE; return i
func _pts_icon() -> Control:
	var i = CurIcon.new(); i.kind = "points"; i.custom_minimum_size = Vector2(26, 26); i.mouse_filter = Control.MOUSE_FILTER_IGNORE; return i
func refresh_currency() -> void:
	for l in currency_labels:
		if not is_instance_valid(l): continue
		match l.get_meta("cur"):
			"coins": l.text = Sys.fmt(Sys.D().coins)
			"points": l.text = Sys.fmt(Sys.D().points)
			"level": l.text = "LVL %d" % Sys.D().profile.level

func hints(extra := "") -> Control:
	var h = hb(22)
	h.add_child(_key_hint(Pad.glyph("A"), "Select (Enter)")); h.add_child(_key_hint(Pad.glyph("B"), "Back (Esc)"))
	h.add_child(spacer())
	if extra != "": h.add_child(label(extra, 13, DIM))
	var m = MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 36)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(h); return m
func _key_hint(k: String, t: String) -> HBoxContainer:
	var kc = PanelContainer.new(); kc.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.85), Color(0, 0, 0, 0), 0, 11, Vector4(7, 1, 7, 1)))
	kc.add_child(bold(k, 11, Color("#111111")))
	return hb(6, [kc, label(t, 13, Color("#cfd6de"))])

## full-screen page frame: top bar + body + hints. Returns {node, body, top}
func frame(top: Control, hint_extra := "", bg_style := "") -> Dictionary:
	var page = Control.new()
	if bg_style == "gold":
		var tint = ColorRect.new(); tint.set_anchors_preset(Control.PRESET_FULL_RECT); tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.color = Color(0.2, 0.15, 0.04, 0.35); page.add_child(tint)
	var v = vb(0); v.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(v)
	var tm = MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 36); tm.add_theme_constant_override("margin_right", 36); tm.add_theme_constant_override("margin_top", 18)
	tm.add_child(top); v.add_child(tm)
	var bm = MarginContainer.new(); bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 36); bm.add_theme_constant_override("margin_right", 36); bm.add_theme_constant_override("margin_top", 14); bm.add_theme_constant_override("margin_bottom", 10)
	var body = vb(14); bm.add_child(body)
	if mobile:
		for s in ["left", "right"]: tm.add_theme_constant_override("margin_" + s, 12); bm.add_theme_constant_override("margin_" + s, 12)
		tm.add_theme_constant_override("margin_top", 8); bm.add_theme_constant_override("margin_top", 8); bm.add_theme_constant_override("margin_bottom", 24)
		var ps = ScrollContainer.new(); ps.size_flags_vertical = Control.SIZE_EXPAND_FILL; ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ps.follow_focus = false; ps.set_meta("page_scroll", true)
		bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ps.add_child(bm); v.add_child(ps)
	else:
		v.add_child(bm)
		v.add_child(hints(hint_extra))
	return {"node": page, "body": body, "v": v}

func hub_shell(tab: String) -> Dictionary:
	if mobile: return _hub_shell_mobile(tab)
	var top = hb(14)
	top.add_child(icon("badge", Sys.D().profile.badge, Vector2(50, 54)))
	top.add_child(_sepline())
	top.add_child(caps(Pad.glyph("LB") if Pad.style == "ps" else "Q", 10))
	for t in HUB_TABS:
		var b = btn(t[1], func(): if t[0] != tab: Sfx.play("tab"); replace(t[0]), "Tab")
		if t[0] == tab:
			b.add_theme_color_override("font_color", Color.WHITE)
			b.add_theme_stylebox_override("normal", _underline())
		if t[0] == "objectives" and Sys.obj_claimable() > 0: b.text += " •"
		if t[0] == "season" and Season.claim_count() > 0: b.text += " •"
		top.add_child(b)
	top.add_child(caps(Pad.glyph("RB") if Pad.style == "ps" else "E", 10))
	top.add_child(spacer()); top.add_child(cloud_btn()); top.add_child(currency_bar())
	var f = frame(top, ("L1 / R1  tabs  ·  L2 / R2  sub-tabs  ·  R-stick scroll" if Pad.style == "ps" else ("LB / RB  tabs  ·  LT / RT  sub-tabs  ·  R-stick scroll" if Pad.style == "xbox" else "Q / E  switch tab")))
	return f
func _hub_shell_mobile(tab: String) -> Dictionary:
	var pr: Dictionary = Sys.D().profile
	var title = vb(0, [caps("Ultimate XI", 10, Color("#8a93a3")), bold(pr.club_name, 17)])
	var top = hb(8, [icon("badge", pr.badge, Vector2(34, 38)), title, spacer(), currency_bar()])
	var f = frame(top)
	f.v.add_child(_bottom_nav(tab))
	return f

func _sub_shell_mobile(title: String, subtitle: String) -> Dictionary:
	var back_b = btn("‹", func(): if cur_back.is_valid(): Sfx.play("back"); cur_back.call(), "Small")
	back_b.custom_minimum_size = Vector2(40, 38); back_b.add_theme_font_size_override("font_size", 26)
	var t = vb(0, [caps(subtitle, 10, Color("#8a93a3")), bold(title, 17)]); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top = hb(8, [back_b, t, currency_bar()])
	var f = frame(top)
	f.v.add_child(_bottom_nav(""))
	return f

## bottom navigation (companion on a phone): Home · Squad · SBC · Market · Store · More
const NAV := [["home", "Home", "home"], ["squad", "Squad", "shirt"], ["sbc", "SBC", "puzzle"], ["transfers", "Market", "swap"], ["store", "Store", "bag"], ["more", "More", "dots"]]
func _bottom_nav(tab: String) -> Control:
	var bar = PanelContainer.new()
	var sb = _sb(Color("#0b1018"), Color(1, 1, 1, 0.08), 0, 0, Vector4(4, 6, 4, 14)); sb.border_width_top = 1
	bar.add_theme_stylebox_override("panel", sb)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 0); bar.add_child(row)
	var active: String = tab if tab != "" else cur_name
	if active in ["objectives", "season", "play", "club", "evolutions", "rivals", "champions", "squadbattles", "gallery", "cloud", "more"]: active = "more"
	for it in NAV:
		var on: bool = it[0] == active
		var b = Button.new(); b.flat = true; b.focus_mode = Control.FOCUS_NONE; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 52
		for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var ic = NavIcon.new(); ic.kind = it[2]; ic.on = on; ic.custom_minimum_size = Vector2(26, 24); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := ""
		if it[0] == "store" and not Sys.D().unopened.is_empty(): badge = str(Sys.D().unopened.size())
		if it[0] == "more" and (Sys.obj_claimable() > 0 or Season.claim_count() > 0): badge = "•"
		var lb = label(it[1] + ((" " + badge) if badge != "" else ""), 11, TEAL if on else Color("#8a93a3"), font_bold); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v = vb(2, [ic, lb]); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_child(v)
		var key: String = it[0]
		b.pressed.connect(func():
			Sfx.play("tab")
			if key == "squad": go("squad")
			else: reset(key))
		row.add_child(b)
	return bar

class NavIcon extends Control:
	var kind = "home"
	var on = false
	func _draw() -> void:
		var c = size / 2; var col = UI.TEAL if on else Color("#8a93a3"); var w = 2.0
		match kind:
			"home":
				draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(0, -9), c + Vector2(9, 0)]), col, w, true)
				draw_polyline(PackedVector2Array([c + Vector2(-6, -2), c + Vector2(-6, 9), c + Vector2(6, 9), c + Vector2(6, -2)]), col, w, true)
			"shirt":
				draw_polyline(PackedVector2Array([c + Vector2(-4, -9), c + Vector2(-11, -5), c + Vector2(-8, 0), c + Vector2(-6, -2), c + Vector2(-6, 9), c + Vector2(6, 9), c + Vector2(6, -2), c + Vector2(8, 0), c + Vector2(11, -5), c + Vector2(4, -9), c + Vector2(0, -6), c + Vector2(-4, -9)]), col, w, true)
			"puzzle":
				draw_rect(Rect2(c + Vector2(-9, -9), Vector2(18, 18)), col, false, w)
				draw_arc(c + Vector2(0, -9), 3.5, PI, TAU, 8, col, w); draw_arc(c + Vector2(9, 0), 3.5, -PI / 2, PI / 2, 8, col, w)
			"swap":
				draw_line(c + Vector2(-9, -4), c + Vector2(8, -4), col, w); draw_polyline(PackedVector2Array([c + Vector2(4, -8), c + Vector2(8, -4), c + Vector2(4, 0)]), col, w)
				draw_line(c + Vector2(9, 5), c + Vector2(-8, 5), col, w); draw_polyline(PackedVector2Array([c + Vector2(-4, 1), c + Vector2(-8, 5), c + Vector2(-4, 9)]), col, w)
			"bag":
				draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 13)), col, false, w)
				draw_arc(c + Vector2(0, -4), 5, PI, TAU, 10, col, w)
			"dots":
				for k in [-7, 0, 7]: draw_circle(c + Vector2(k, 0), 2.4, col)

func _sepline() -> Control:
	var c = ColorRect.new(); c.color = Color(1, 1, 1, 0.25); c.custom_minimum_size = Vector2(1, 30); return c
func _underline() -> StyleBoxFlat:
	var s = _sb(Color(0, 0, 0, 0), TEAL, 0, 0, Vector4(12, 8, 12, 8)); s.border_width_bottom = 3; return s

## ☁ button: opens the Cloud screen, tinted by sync state
func cloud_btn() -> Button:
	var on: bool = Cloud.signed_in()
	var b = btn(("☁ " + Cloud.username()) if on else "☁ Cloud", func(): go("cloud"), "Small")
	b.add_theme_color_override("font_color", GREEN if on else DIM)
	b.focus_mode = Control.FOCUS_NONE
	return b

func sub_shell(title: String, subtitle := "Ultimate XI", gold := false) -> Dictionary:
	if mobile and Save.data != null: return _sub_shell_mobile(title, subtitle)
	var top = hb(14)
	top.add_child(icon("badge", Sys.D().profile.badge, Vector2(44, 48)))
	top.add_child(vb(0, [caps(subtitle, 12), bold(title, 24)]))
	top.add_child(spacer()); top.add_child(currency_bar())
	return frame(top, "", "gold" if gold else "")

# ------------------------------------------------------------------ toast & modal
func toast(msg: String, kind := "info") -> void:
	if Sys.quiet: return
	# keep the stack short so pop-ups never cover the screen
	while toasts.get_child_count() >= 4:
		var old = toasts.get_child(0); toasts.remove_child(old); old.queue_free()
	var col = GREEN if kind == "good" else (RED if kind == "bad" else Color("#3ea6ff"))
	var p = PanelContainer.new()
	var sb = _sb(Color(0.055, 0.08, 0.11, 0.96), Color(1, 1, 1, 0.09), 1, 10, Vector4(14, 10, 14, 10)); sb.border_width_left = 4; sb.border_color = col
	p.add_theme_stylebox_override("panel", sb)
	var l = wrapl(label(msg, 14), 370); p.add_child(l)
	toasts.add_child(p)
	p.modulate.a = 0
	var tw = p.create_tween(); tw.tween_property(p, "modulate:a", 1.0, 0.2); tw.tween_interval(2.8); tw.tween_property(p, "modulate:a", 0.0, 0.4); tw.tween_callback(p.queue_free)

## per-screen shortcut keys / pad buttons: {"k<keycode>": Callable, "j<joy button>": Callable}
class KeyHook extends Node:
	var map = {}
	func _unhandled_input(e: InputEvent) -> void:
		if not UI.modals.is_empty() or UI.in_match: return
		var k = ""
		if e is InputEventKey and e.pressed and not e.echo: k = "k%d" % e.physical_keycode
		elif e is InputEventJoypadButton and e.pressed: k = "j%d" % e.button_index
		if k != "" and map.has(k):
			var fo = get_viewport().gui_get_focus_owner()
			if fo is LineEdit and e is InputEventKey: return
			get_viewport().set_input_as_handled(); map[k].call()
func keyhook(node: Node, map: Dictionary) -> void:
	var h = KeyHook.new(); h.map = map; node.add_child(h)

class ModalHandle extends RefCounted:
	signal closed(v)

## buttons: [[label, value, variant], ...]; a button whose value is null acts as cancel
func modal(title: String, body, buttons := [["OK", true, "Primary"]], wide := false):
	var h = ModalHandle.new()
	var back = ColorRect.new(); back.color = Color(0.01, 0.015, 0.03, 0.78); back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	var center = CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); back.add_child(center)
	var pnl = PanelContainer.new(); pnl.add_theme_stylebox_override("panel", _sb(Color("#141c26"), Color(1, 1, 1, 0.12), 1, 18, Vector4(26, 22, 26, 22)))
	pnl.custom_minimum_size = Vector2(1100 if wide else 420, 0)
	if mobile: pnl.custom_minimum_size.x = min(pnl.custom_minimum_size.x, root.size.x - 16)
	center.add_child(pnl)
	var v = vb(14); pnl.add_child(v)
	if title != "": v.add_child(head(title.to_upper(), 22))
	var b: Control = body if body is Control else wrapl(label(str(body), 15), 520 if not wide else 1000)
	if wide or (b is Control and b.custom_minimum_size.y > 600):
		var sc = ScrollContainer.new(); sc.custom_minimum_size = Vector2(0, min(640, root.size.y - 240)); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.follow_focus = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(b); v.add_child(sc)
	else: v.add_child(b)
	var bh = hb(10); bh.alignment = BoxContainer.ALIGNMENT_END; v.add_child(bh)
	var done = [false]
	var prev_focus = get_viewport().gui_get_focus_owner()
	var close = func(val):
		if done[0]: return
		done[0] = true
		for i in modals.size():
			if modals[i].node == back: modals.remove_at(i); break
		back.queue_free()
		if is_instance_valid(prev_focus) and prev_focus.is_visible_in_tree(): prev_focus.grab_focus()
		h.closed.emit(val)
	var cancel_val = null
	for bt in buttons:
		var val = bt[1]
		var bb = btn(bt[0], func(): close.call(val), bt[2] if bt.size() > 2 else "")
		bh.add_child(bb)
	modals.append({"node": back, "cancel": func(): Sfx.play("back"); close.call(cancel_val)})
	overlay.add_child(back)
	h.set_meta("close", close)
	back.set_meta("close", close)
	await get_tree().process_frame
	if is_instance_valid(back):
		var af = _find_auto(back)
		if af: af.grab_focus()
		else:
			var f = _find_focusable(v)
			if f: f.grab_focus()
	return await h.closed

## phone-style bottom sheet: slides up from the bottom; actions are full-width rows.
## actions: [[label, value, variant], ...] — returns the chosen value (null = dismissed)
func sheet(title: String, body: Control, actions: Array):
	var h = ModalHandle.new()
	var back = ColorRect.new(); back.color = Color(0.01, 0.015, 0.03, 0.6); back.set_anchors_preset(Control.PRESET_FULL_RECT); back.mouse_filter = Control.MOUSE_FILTER_STOP
	var pnl = PanelContainer.new()
	var sb = _sb(Color("#121a25"), Color(1, 1, 1, 0.1), 1, 0, Vector4(16, 10, 16, 22)); sb.corner_radius_top_left = 20; sb.corner_radius_top_right = 20; sb.border_width_bottom = 0
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); pnl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back.add_child(pnl)
	var v = vb(10); pnl.add_child(v)
	var grip = ColorRect.new(); grip.color = Color(1, 1, 1, 0.25); grip.custom_minimum_size = Vector2(44, 4); grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grip)
	if title != "": v.add_child(bold(title, 17))
	if body: v.add_child(body)
	var done = [false]
	var close = func(val):
		if done[0]: return
		done[0] = true
		for i in modals.size():
			if modals[i].node == back: modals.remove_at(i); break
		var tw = pnl.create_tween(); tw.tween_property(pnl, "position:y", pnl.position.y + pnl.size.y, 0.16)
		tw.tween_callback(back.queue_free)
		h.closed.emit(val)
	for a in actions:
		var val = a[1]
		var bb = btn(a[0], func(): close.call(val), a[2] if a.size() > 2 else "")
		bb.custom_minimum_size.y = 46; bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(bb)
	back.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and not pnl.get_global_rect().has_point(e.global_position): close.call(null))
	modals.append({"node": back, "cancel": func(): Sfx.play("back"); close.call(null)})
	back.set_meta("close", close)
	overlay.add_child(back)
	await get_tree().process_frame
	if is_instance_valid(pnl):
		var y0 = pnl.position.y; pnl.position.y = y0 + pnl.size.y
		pnl.create_tween().tween_property(pnl, "position:y", y0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return await h.closed

## close the top-most modal with a value (used by pickers whose body has its own buttons)
func close_top(val) -> void:
	if modals.is_empty(): return
	var n: Control = modals[-1].node
	n.get_meta("close").call(val)

# ------------------------------------------------------------------ shared dialogs
func player_row(p: Dictionary, right: Array, cb: Callable) -> Button:
	var b = Button.new(); b.theme_type_variation = "Row"; b.focus_mode = Control.FOCUS_ALL; b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	b.mouse_entered.connect(func(): if mouse_recent() and not b.has_focus(): b.grab_focus())
	var h = hb(12); h.set_anchors_preset(Control.PRESET_FULL_RECT); h.offset_left = 12; h.offset_right = -12
	var ov = PanelContainer.new(); ov.add_theme_stylebox_override("panel", _sb(Data.ovr_color(p), Color(0, 0, 0, 0), 0, 6, Vector4(6, 1, 6, 1)))
	ov.add_child(head(str(p.ovr), 18, Color("#111111") if p.type == "base" else Color.WHITE)); ov.custom_minimum_size.x = 44
	h.add_child(ov)
	var pos = bold(p.pos, 14); pos.custom_minimum_size.x = 40; h.add_child(pos)
	h.add_child(icon("flag", p.nat, Vector2(24, 16))); h.add_child(icon("crest", p.club, Vector2(22, 22)))
	var nm = hb(6, [bold(p.name, 15), label("· " + Data.rarity_name(p), 12, DIM)]); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(nm)
	for r in right: h.add_child(r)
	for c in h.get_children(): c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_child(h); _ignore_mouse(h)
	return b

func inspect(p: Dictionary, actions := [], item := {}):
	var lab = ["Diving", "Handling", "Kicking", "Reflexes", "Speed", "Positioning"] if p.pos == "GK" else ["Pace", "Shooting", "Passing", "Dribbling", "Defending", "Physical"]
	var cl: Dictionary = Data.clubs[p.club]; var lg: Dictionary = Data.leagues.get(p.lg, {})
	var right = vb(8)
	right.add_child(head(p.name.to_upper(), 22))
	if p.has("evo_name") or p.has("evo"): right.add_child(label("Evolved · " + str(p.get("evo_name", "Next Gen")), 13, Color("#7dffb0")))
	right.add_child(label("%s · %s%s" % [Data.rarity_name(p), p.pos, (" (" + ", ".join(p.alt) + ")") if not p.alt.is_empty() else ""], 14, DIM))
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 24); g.add_theme_constant_override("v_separation", 6)
	var kv = func(k: String, v: Control): g.add_child(label(k, 14, DIM)); g.add_child(v)
	kv.call("Nation", hb(6, [icon("flag", p.nat, Vector2(22, 15)), label(Data.nations[p.nat].name, 14)]))
	kv.call("Club", hb(6, [icon("crest", p.club, Vector2(20, 20)), label(cl.name, 14)]))
	kv.call("League", hb(6, [icon("league", p.lg, Vector2(20, 20)), label(lg.get("name", "—"), 14)]) if not lg.is_empty() else label("—", 14))
	kv.call("Age / Height", label("%d yrs · %d cm" % [p.age, p.height], 14))
	kv.call("Preferred foot", label("Left" if p.foot == "L" else "Right", 14))
	kv.call("Skill moves / Weak foot", label("%s · %s" % ["★".repeat(p.sm) + "☆".repeat(5 - p.sm), "★".repeat(p.wf) + "☆".repeat(5 - p.wf)], 14))
	kv.call("Work rates", label("Att %s / Def %s" % [p.wr[0], p.wr[1]], 14))
	kv.call("Market value", label("● " + Sys.fmt(Sys.value(p)), 14, GOLD2))
	kv.call("Gems (SBC & Gallery)", label("✦ %s%s" % [Sys.fmt(Gallery.gems(p)), ("  · in your Gallery" if Gallery.seen(p.id) else "")], 14, Color("#ff6fd8")))
	if p.has("orig_pos"): kv.call("Position change", label("%s → %s (original %s)" % [p.orig_pos, p.pos, p.orig_pos], 14, TEAL))
	if p.has("style"): kv.call("Chemistry style", label("%s  ·  %s at 3 chem" % [p.style, Cons.boost_text(p.style, p.pos == "GK")], 14, Color("#7fd4ff")))
	if not item.is_empty(): kv.call("Status", label("Untradeable" if item.get("untr", false) else "Tradeable", 14, RED if item.get("untr", false) else GREEN))
	right.add_child(g)
	var sg = GridContainer.new(); sg.columns = 3; sg.add_theme_constant_override("h_separation", 26)
	for i in 6:
		var v: int = p.stats[i]
		var c = GREEN if v >= 80 else (YELLOW if v >= 65 else RED)
		var row = hb(8, [bold(lab[i], 14), spacer(), head(str(v), 16, c)]); row.custom_minimum_size.x = 150
		sg.add_child(row)
	right.add_child(sg)
	var body = hb(26, [card(p, 15.0), right])
	var btns = []
	for a in actions: btns.append(a)
	btns.append(["Close", null, ""])
	return await modal("Player Details", body, btns)

func compare(a: Dictionary, b: Dictionary):
	var lab: Array = Data.GK_LABELS if a.pos == "GK" else Data.STAT_LABELS
	var mid = vb(4); mid.custom_minimum_size.x = 220
	for i in 7:
		var x: int = a.ovr if i == 0 else a.stats[i - 1]; var y: int = b.ovr if i == 0 else b.stats[i - 1]; var d = x - y
		mid.add_child(hb(6, [bold(str(x), 15), spacer(), label("OVR" if i == 0 else lab[i - 1], 12, DIM), spacer(), bold(str(y), 15), label(("▲%d" % d) if d > 0 else (("▼%d" % -d) if d < 0 else "="), 12, GREEN if d > 0 else (RED if d < 0 else DIM))]))
	await modal("Compare", hb(24, [card(a, 12.0), mid, card(b, 12.0)]), [["Close", null, "Primary"]], true)

## pick a club item. filter: Callable(item)->bool. Returns uid or null
func pick_player(title: String, pos := "", filter = null, allow_untr := true):
	var items: Array = Sys.D().club.filter(func(it): return not Sys.in_market(it.uid) and (allow_untr or not it.untr) and (filter == null or filter.call(it)))
	var state = {"q": "", "pos": pos, "sort": "fit"}
	var list = vb(6)
	var render = func():
		for c in list.get_children(): c.queue_free()
		var arr = items.map(func(it): return [it, Cons.item_view(it)]).filter(func(x): return (state.q == "" or x[1].name.to_lower().contains(state.q)) and (state.pos == "" or Data.fits_pos(x[1], state.pos)))
		if state.sort == "fit" and pos != "":
			arr.sort_custom(func(a, b): return (int(b[1].pos == pos) * 20 + int(Data.fits_pos(b[1], pos)) * 10 + b[1].ovr) < (int(a[1].pos == pos) * 20 + int(Data.fits_pos(a[1], pos)) * 10 + a[1].ovr))
		elif state.sort == "new": arr.sort_custom(func(a, b): return a[0].at > b[0].at)
		else: arr.sort_custom(func(a, b): return a[1].ovr > b[1].ovr)
		if arr.is_empty(): list.add_child(label("No players match. Open packs or buy from the Transfer Market.", 14, DIM))
		for x in arr.slice(0, 120):
			var tags = []
			if x[0].untr: tags.append(pill("UNTR", RED))
			if Sys.in_active_squad(x[0].uid): tags.append(pill("IN SQUAD"))
			var u: String = x[0].uid
			list.add_child(player_row(x[1], tags, func(): close_top(u)))
	var top = hb(8)
	var q = line("", func(t): state.q = t.to_lower(); render.call(), "Search name", 240); top.add_child(q)
	top.add_child(option([["", "All positions"]] + Data.positions.map(func(x): return [x, x]), pos, func(v): state.pos = v; render.call()))
	top.add_child(option([["fit", "Best fit"], ["ovr", "Rating"], ["new", "Newest"]], "fit", func(v): state.sort = v; render.call()))
	render.call()
	var body = vb(10, [top, list])
	return await modal(title, body, [["Cancel", null, ""]], true)

# ------------------------------------------------------------------ match glue (implemented in hub2)
func run_match(cfg: Dictionary, cb: Callable) -> void: modules[2].run_match(cfg, cb)
func compare_price(p: Dictionary) -> void: await modules[7].compare_price(p)
func show_results(res: Dictionary, title: String, rewards: String, cb: Callable) -> void: modules[2].show_results(res, title, rewards, cb)


# ------------------------------------------------------------------ MOBILE (companion on a phone)
## On a portrait phone the companion renders on a phone-sized canvas (440 px wide), so everything is
## readable. Pages scroll vertically, the hub tabs become a swipeable strip, and any row that is wider
## than the screen wraps onto the next line (a pass over every new screen, modal and list).
const MOBILE_W := 440
var mobile = false
var _reflow_pending = false

func _mobile_setup() -> void:
	if not Cloud.companion(): return
	# only draw a new frame when something changed: saves the phone's GPU/battery so it doesn't throttle mid-scroll
	OS.low_processor_usage_mode = true
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if OS.has_feature("web"):
		# ask the browser directly: the canvas can report its size late on iPhone
		var js = JavaScriptBridge.eval("[window.innerWidth, window.innerHeight].join(',')", true)
		if typeof(js) == TYPE_STRING and js.contains(","):
			var parts = js.split(","); win = Vector2(float(parts[0]), float(parts[1]))
	var portrait: bool = win.y > win.x * 1.1 or (OS.has_feature("web") and win.x > 0 and win.x < 700)
	var want: bool = portrait
	var r = get_tree().root
	if want:
		r.content_scale_size = Vector2i(MOBILE_W, 780)
		r.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		r.content_scale_size = Vector2i(1600, 900)
	if want != mobile:
		mobile = want
		if cur_name != "": rerender.call_deferred()
	toasts.position = Vector2(10, 70) if mobile else Vector2(root.size.x - 430, 80)
	toasts.custom_minimum_size.x = (MOBILE_W - 20) if mobile else 400
	if not get_viewport().size_changed.is_connected(_mobile_setup):
		get_viewport().size_changed.connect(_mobile_setup)
		for d in [0.3, 1.0, 2.5]: get_tree().create_timer(d).timeout.connect(_mobile_setup)

func _on_node_added(n: Node) -> void:
	if n is LineEdit and OS.has_feature("web"): _hook_web_input(n)
	if not mobile or _reflow_pending or not (n is Control): return
	_reflow_pending = true
	_reflow_all.call_deferred()

func _reflow_all() -> void:
	_reflow_pending = false
	if not mobile: return
	await get_tree().process_frame
	var avail: float = root.size.x - 24.0
	if is_instance_valid(cur): _wrap_custom_page(cur); _reflow(cur, avail)
	for m in modals: if is_instance_valid(m.node): _reflow(m.node, avail)

## screens that don't use frame() (Rivals, Champions…) still get a vertical page scroll
func _wrap_custom_page(page: Control) -> void:
	if page.has_meta("mobile_wrapped"): return
	page.set_meta("mobile_wrapped", true)
	for c in page.get_children():
		if c is MarginContainer and c.anchor_right == 1.0 and c.anchor_bottom == 1.0 and not (c.get_parent() is ScrollContainer):
			var idx = c.get_index()
			var ps = ScrollContainer.new(); ps.set_anchors_preset(Control.PRESET_FULL_RECT); ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			ps.follow_focus = false; ps.set_meta("page_scroll", true)
			page.remove_child(c); c.set_anchors_preset(Control.PRESET_TOP_LEFT); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for s in ["left", "right"]: c.add_theme_constant_override("margin_" + s, 12)
			ps.add_child(c); page.add_child(ps); page.move_child(ps, idx)

func _h_scroll_ancestor(n: Node) -> bool:
	var p = n.get_parent()
	while p != null:
		if p is ScrollContainer and p.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and not p.has_meta("page_scroll"): return true
		p = p.get_parent()
	return false

func _reflow(n: Node, avail: float) -> void:
	for c in n.get_children(): _reflow(c, avail)
	if not (n is Control): return
	var ctl: Control = n
	var leaf: float = avail - 56.0   # room left inside padded panels
	if ctl is PitchView:
		if ctl.custom_minimum_size.x > leaf: ctl.custom_minimum_size = Vector2(leaf, leaf * 1.05)
		return
	if ctl is Label:
		var lb: Label = ctl
		if lb.get_combined_minimum_size().x > leaf:
			if lb.autowrap_mode == TextServer.AUTOWRAP_OFF: lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lb.custom_minimum_size.x = leaf
		return
	if ctl is ScrollContainer:
		# inner scrolls grow to their content; the page itself scrolls
		if not ctl.has_meta("page_scroll") and not ctl.has_meta("keep_scroll") and ctl.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: ctl.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ctl.follow_focus = false   # phones: a selected item never yanks the page back
		return
	if _h_scroll_ancestor(ctl): return
	# menu tiles use the full width of the phone
	if ctl is Button and ctl.theme_type_variation == "Tile" and not (ctl.get_parent() is GridContainer): ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ctl is GridContainer:
		while ctl.columns > 1 and ctl.get_combined_minimum_size().x > avail: ctl.columns -= 1
		return
	if ctl is HBoxContainer and not ctl.has_meta("flowed") and not ctl.has_meta("keep_row") and ctl.get_child_count() > 1 and ctl.get_combined_minimum_size().x > avail:
		# wrap: move the row's children into a flow container that breaks onto new lines
		var fl = HFlowContainer.new(); fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sep = ctl.get_theme_constant("separation")
		fl.add_theme_constant_override("h_separation", sep); fl.add_theme_constant_override("v_separation", max(6, sep))
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in ctl.get_children():
			if c is Control and c.size_flags_horizontal & Control.SIZE_EXPAND and c.get_combined_minimum_size().x < 40: continue   # spacers would eat a line
			ctl.remove_child(c); fl.add_child(c)
		for c in ctl.get_children(): ctl.remove_child(c); c.queue_free()
		ctl.add_child(fl); ctl.set_meta("flowed", true)
		return
	if ctl.custom_minimum_size.x > leaf:
		var hgt: float = ctl.custom_minimum_size.y
		if not (ctl is Container) and hgt > 0 and ctl.custom_minimum_size.x > 0 and not (ctl is BaseButton):
			ctl.custom_minimum_size.y = hgt * leaf / ctl.custom_minimum_size.x   # keep art proportions
		ctl.custom_minimum_size.x = leaf


# ------------------------------------------------------------------ WEB TEXT INPUT (phones)
## Godot's canvas can't reliably raise the iPhone keyboard, so on the web every text field opens a
## native HTML input box over the game instead. The answer is written back into the LineEdit.
const _JS_ASK := """
window.pfAsk = function(title, value, secret, numeric, maxlen) {
  window.pfAns = null;
  var old = document.getElementById('pf-ask'); if (old) old.remove();
  var bg = document.createElement('div'); bg.id = 'pf-ask';
  bg.style.cssText = 'position:fixed;inset:0;z-index:99999;background:rgba(5,8,14,.82);display:flex;align-items:flex-start;justify-content:center;padding-top:18vh;font-family:-apple-system,Segoe UI,Arial,sans-serif';
  var box = document.createElement('div');
  box.style.cssText = 'width:86vw;max-width:420px;background:#141c27;border:1px solid rgba(255,255,255,.12);border-radius:16px;padding:18px;box-shadow:0 10px 40px rgba(0,0,0,.6)';
  var t = document.createElement('div'); t.textContent = title; t.style.cssText = 'color:#eef2f6;font-weight:800;font-size:17px;margin-bottom:12px';
  var inp = document.createElement('input'); inp.value = value || '';
  inp.type = secret ? 'password' : 'text'; if (numeric) { inp.inputMode = 'numeric'; inp.pattern = '[0-9]*'; }
  if (maxlen > 0) inp.maxLength = maxlen;
  inp.autocapitalize = 'off'; inp.autocomplete = 'off'; inp.spellcheck = false;
  inp.style.cssText = 'width:100%;box-sizing:border-box;font-size:18px;padding:12px 14px;border-radius:10px;border:2px solid #3fe0c5;background:#0b1018;color:#fff;outline:none';
  var row = document.createElement('div'); row.style.cssText = 'display:flex;gap:10px;margin-top:14px;justify-content:flex-end';
  function mk(label, primary) { var b = document.createElement('button'); b.textContent = label;
    b.style.cssText = 'font-size:16px;font-weight:700;padding:10px 18px;border-radius:10px;border:0;' + (primary ? 'background:#eef2f6;color:#111' : 'background:#2a3442;color:#eef2f6'); return b; }
  var cancel = mk('Cancel', false), ok = mk('OK', true);
  function done(v) { window.pfAns = v; bg.remove(); }
  cancel.onclick = function(){ done('__pf_cancel__'); };
  ok.onclick = function(){ done(inp.value); };
  inp.onkeydown = function(e){ if (e.key === 'Enter') done(inp.value); };
  bg.onclick = function(e){ if (e.target === bg) done('__pf_cancel__'); };
  row.appendChild(cancel); row.appendChild(ok); box.appendChild(t); box.appendChild(inp); box.appendChild(row); bg.appendChild(box);
  document.body.appendChild(bg); setTimeout(function(){ inp.focus(); }, 30);
};
"""
var _js_ready = false
var _asking = false

func _hook_web_input(le: LineEdit) -> void:
	if le.has_meta("web_input"): return
	le.set_meta("web_input", true)
	le.virtual_keyboard_enabled = false
	le.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			le.accept_event(); _web_ask(le))


func _web_ask(le: LineEdit) -> void:
	if _asking or not is_instance_valid(le) or not le.editable: return
	_asking = true
	if not _js_ready: JavaScriptBridge.eval(_JS_ASK, true); _js_ready = true
	var title: String = le.placeholder_text if le.placeholder_text != "" else "Type here"
	var p = le.get_parent()
	if p is VBoxContainer and p.get_child_count() > 0 and p.get_child(0) is Label and p.get_child(0) != le: title = (p.get_child(0) as Label).text.capitalize()
	JavaScriptBridge.eval("pfAsk(%s, %s, %s, %s, %d)" % [JSON.stringify(title), JSON.stringify(le.text), "true" if le.secret else "false", "true" if le.secret and le.max_length > 0 and le.max_length <= 8 else "false", le.max_length], true)
	var ans = null
	while ans == null:
		await get_tree().process_frame
		ans = JavaScriptBridge.eval("window.pfAns", true)
	_asking = false
	le.release_focus()
	if not is_instance_valid(le) or typeof(ans) != TYPE_STRING or ans == "__pf_cancel__": return
	le.text = ans
	le.text_changed.emit(ans)
	le.text_submitted.emit(ans)


# ------------------------------------------------------------------ phone widgets
## dark rounded card with an optional coloured top edge
func m_card(child: Control, accent := Color(0, 0, 0, 0), pad := 14) -> PanelContainer:
	var pn = PanelContainer.new()
	var sb = _sb(Color("#141c27"), Color(1, 1, 1, 0.07), 1, 14, Vector4(pad, pad - 2, pad, pad))
	if accent.a > 0: sb.border_width_top = 3; sb.border_color = accent
	pn.add_theme_stylebox_override("panel", sb); pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pn.add_child(child); return pn
## small stat chip: big value + caption
func m_chip(val: String, cap: String, col := TEXT) -> PanelContainer:
	var v = vb(0, [head(val, 20, col), caps(cap, 9, Color("#8a93a3"))])
	for c in v.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pn = PanelContainer.new(); pn.add_theme_stylebox_override("panel", _sb(Color("#141c27"), Color(1, 1, 1, 0.07), 1, 12, Vector4(8, 6, 8, 6)))
	pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pn.add_child(v); return pn
## big full-width call-to-action button
func m_cta(text: String, cb: Callable, variant := "Primary") -> Button:
	var b = btn(text, cb, variant, true); b.custom_minimum_size.y = 54; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18); return b
