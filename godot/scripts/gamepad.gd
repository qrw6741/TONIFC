extends Node
## GAMEPAD — controller support with first-class PS5 DualSense (and DualShock 4) handling:
## • registers SDL mappings for DualSense / DualSense Edge / DualShock 4 on Windows, Linux & macOS
##   (so Cross/Circle/Square/Triangle, L1/R1, L2/R2, Options and the D-pad map correctly
##   even when the OS driver reports raw DirectInput/HID buttons)
## • tracks whichever controller you last touched (works with any device index)
## • shows PlayStation glyphs (✕ ○ □ △, L1/R1, R2, Options) when a PlayStation pad is in use
## • rumble on goals, saves, tackles and shots (toggle in Settings)

signal style_changed

var device = -1          # last-used joypad id (-1 = none)
var style = ""           # "ps", "xbox" or "" (keyboard / no pad)

const MAPPINGS := [
	# DualSense (PS5) — USB & Bluetooth
	"030000004c050000e60c000000000000,PS5 Controller,a:b1,b:b2,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,misc1:b14,rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,start:b9,touchpad:b13,x:b0,y:b3,platform:Windows,",
	"030000004c050000f20d000000000000,PS5 Edge Controller,a:b1,b:b2,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,misc1:b14,rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,start:b9,touchpad:b13,x:b0,y:b3,platform:Windows,",
	"050000004c050000e60c000000810000,PS5 Controller,a:b0,b:b1,back:b8,dpdown:b14,dpleft:b15,dpright:b16,dpup:b13,guide:b10,leftshoulder:b4,leftstick:b11,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b12,righttrigger:a5,rightx:a3,righty:a4,start:b9,x:b3,y:b2,platform:Linux,",
	"030000004c050000e60c000011810000,PS5 Controller,a:b0,b:b1,back:b8,dpdown:b14,dpleft:b15,dpright:b16,dpup:b13,guide:b10,leftshoulder:b4,leftstick:b11,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b12,righttrigger:a5,rightx:a3,righty:a4,start:b9,x:b3,y:b2,platform:Linux,",
	"030000004c050000e60c000000010000,PS5 Controller,a:b1,b:b2,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,start:b9,touchpad:b13,x:b0,y:b3,platform:Mac OS X,",
	# DualShock 4 (PS4)
	"030000004c050000cc09000000000000,PS4 Controller,a:b1,b:b2,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,start:b9,touchpad:b13,x:b0,y:b3,platform:Windows,",
	"030000004c050000c405000000000000,PS4 Controller,a:b1,b:b2,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,start:b9,touchpad:b13,x:b0,y:b3,platform:Windows,",
]

const PS_GLYPH := {"A": "✕", "B": "○", "X": "□", "Y": "△", "LB": "L1", "RB": "R1", "LT": "L2", "RT": "R2", "START": "OPTIONS", "BACK": "CREATE", "RS": "R3 / Right stick", "LS": "Left stick"}
const XB_GLYPH := {"A": "A", "B": "B", "X": "X", "Y": "Y", "LB": "LB", "RB": "RB", "LT": "LT", "RT": "RT", "START": "Start", "BACK": "Back", "RS": "Right stick", "LS": "Left stick"}

func _ready() -> void:
	for m in MAPPINGS: Input.add_joy_mapping(m, true)
	Input.joy_connection_changed.connect(_on_conn)
	var pads = Input.get_connected_joypads()
	if not pads.is_empty(): _set_device(pads[0], false)
	_ensure_ui_actions()

## make sure menu navigation works with every controller (Cross = accept, Circle = back, D-pad & left stick move)
func _ensure_ui_actions() -> void:
	var add = func(action: String, ev: InputEvent):
		for e in InputMap.action_get_events(action): if e.is_match(ev, true): return
		InputMap.action_add_event(action, ev)
	var jb = func(b): var e = InputEventJoypadButton.new(); e.button_index = b; e.device = -1; return e
	var ja = func(axis, v): var e = InputEventJoypadMotion.new(); e.axis = axis; e.axis_value = v; e.device = -1; return e
	add.call("ui_accept", jb.call(JOY_BUTTON_A))
	add.call("ui_cancel", jb.call(JOY_BUTTON_B))
	add.call("ui_up", jb.call(JOY_BUTTON_DPAD_UP)); add.call("ui_up", ja.call(JOY_AXIS_LEFT_Y, -1.0))
	add.call("ui_down", jb.call(JOY_BUTTON_DPAD_DOWN)); add.call("ui_down", ja.call(JOY_AXIS_LEFT_Y, 1.0))
	add.call("ui_left", jb.call(JOY_BUTTON_DPAD_LEFT)); add.call("ui_left", ja.call(JOY_AXIS_LEFT_X, -1.0))
	add.call("ui_right", jb.call(JOY_BUTTON_DPAD_RIGHT)); add.call("ui_right", ja.call(JOY_AXIS_LEFT_X, 1.0))

func _on_conn(id: int, connected: bool) -> void:
	if connected:
		_set_device(id, true)
	elif id == device:
		var pads = Input.get_connected_joypads()
		if pads.is_empty(): device = -1; _set_style("")
		else: _set_device(pads[0], false)

func _set_device(id: int, announce: bool) -> void:
	device = id
	var n = Input.get_joy_name(id)
	_set_style(_style_for(n))
	if announce and is_instance_valid(UI) and UI.root:
		UI.toast(("PlayStation controller connected — ✕ select · ○ back" if style == "ps" else "Controller connected: " + n), "good")
		rumble(0.3, 0.3, 0.25)

func _style_for(n: String) -> String:
	var l = n.to_lower()
	for k in ["ps5", "ps4", "dualsense", "dualshock", "sony", "playstation", "wireless controller", "ps3"]:
		if l.contains(k): return "ps"
	return "xbox"

func _set_style(s: String) -> void:
	if s != style: style = s; style_changed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
		if event.device != device: _set_device(event.device, false)
		elif style == "": _set_style(_style_for(Input.get_joy_name(device)))

func glyph(k: String) -> String:
	return (PS_GLYPH if style == "ps" else XB_GLYPH).get(k, k)

## active controller id for in-match reads (falls back to the first connected pad)
func id() -> int:
	if device >= 0 and Input.get_connected_joypads().has(device): return device
	var pads = Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else 0

func rumble(weak: float, strong: float, dur: float) -> void:
	if Save.data and not Save.data.settings.get("vibration", true): return
	if device >= 0: Input.start_joy_vibration(device, weak, strong, dur)
