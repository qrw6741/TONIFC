extends Control
## Match scene: runs MatchSim at a fixed 60 Hz, reads keyboard/controller input,
## renders the broadcast camera view (stands, crowd, LED boards, pitch, goals & nets,
## players, referee, ball) and the HUD (scoreboard, clock, player panel, power bar,
## radar, messages, goal banner, controls). Esc / Start opens pause & substitutions.

var sim: MatchSim
var on_done: Callable
var cam = Vector2(52.5, 34.0)
var crowd = []
var acc = 0.0
var prev_in = {}
var taps = {}
var help_on = true
var CC = {}
var hud = {}
var stadium = {}
var tifo_cols = []
var done = false

func setup(cfg: Dictionary, cb: Callable) -> void:
	sim = MatchSim.new(cfg); on_done = cb
	sim.ended.connect(_finish)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP
	UI.in_match = true; UI.bg.set_mode("off"); UI.host.visible = false
	Sfx.music_off(); Sfx.crowd_on()
	var pr: Dictionary = Save.data.profile
	var user_match: bool = sim.teams.home.user or sim.teams.away.user
	stadium = pr.stadium if user_match else {"seats": "#2a2f3a", "tifo": "none", "theme": "classic", "name": "PRIME FOOTBALL 27"}
	tifo_cols = [Color(pr.badge.c1), Color(pr.badge.c2)]
	_build_crowd(); _build_hud()

func _build_crowd() -> void:
	var seat = Color(stadium.seats); var ka = Color(sim.teams.home.kit.c1); var kb = Color(sim.teams.away.kit.c1)
	for i in 1900:
		var c: Color
		var r = randf()
		if r < 0.18: c = seat
		elif r < 0.62: c = ka
		elif r < 0.81: c = kb
		else: c = [Color("#dddddd"), Color("#888888"), Color("#c9b28a")][randi() % 3]
		crowd.append({"k": 0, "u": randf(), "v": randf(), "c": c, "ph": randf() * 6})
	for i in 900:
		var side = i % 2
		crowd.append({"k": 2 if side else 1, "u": randf(), "v": randf(), "c": (kb if side else ka) if randf() < 0.7 else Color("#aaaaaa"), "ph": randf() * 6})

func _panel(bgc: Color, pad := Vector4(10, 6, 10, 6), radius := 6) -> PanelContainer:
	var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", UI._sb(bgc, Color(0, 0, 0, 0), 0, radius, pad)); return p

func _build_hud() -> void:
	var sb = HBoxContainer.new(); sb.add_theme_constant_override("separation", 0); sb.position = Vector2(22, 18)
	var clock = _panel(Color("#111111")); hud.clock = UI.head("00:00", 17); hud.clock.custom_minimum_size.x = 60; hud.clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; clock.add_child(hud.clock); sb.add_child(clock)
	var k1 = ColorRect.new(); k1.color = Color(sim.teams.home.kit.c1); k1.custom_minimum_size = Vector2(6, 0); sb.add_child(k1)
	var h = _panel(Color(0.96, 0.96, 0.96)); h.add_child(UI.head(sim.teams.home.short, 17, Color("#111111"))); sb.add_child(h)
	var sc = _panel(Color("#1d2733")); hud.score = UI.head("0 - 0", 19); hud.score.custom_minimum_size.x = 64; hud.score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sc.add_child(hud.score); sb.add_child(sc)
	var a = _panel(Color(0.96, 0.96, 0.96)); a.add_child(UI.head(sim.teams.away.short, 17, Color("#111111"))); sb.add_child(a)
	var k2 = ColorRect.new(); k2.color = Color(sim.teams.away.kit.c1); k2.custom_minimum_size = Vector2(6, 0); sb.add_child(k2)
	add_child(sb)
	hud.msg = _panel(Color(0.04, 0.055, 0.08, 0.85), Vector4(18, 8, 18, 8), 99); hud.msg_l = UI.bold("", 14); hud.msg.add_child(hud.msg_l); add_child(hud.msg)
	hud.banner = CenterContainer.new(); hud.banner.set_anchors_preset(Control.PRESET_FULL_RECT); hud.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(hud.banner)
	hud.player = _panel(Color(0.04, 0.055, 0.08, 0.82), Vector4(14, 9, 14, 9), 10)
	var pv = UI.vb(6); hud.pname = UI.bold("", 14); hud.stam = UI.bar(1, 1); hud.stam.custom_minimum_size = Vector2(220, 5)
	pv.add_child(hud.pname); pv.add_child(hud.stam); hud.player.add_child(pv); add_child(hud.player)
	hud.power = UI.bar(0, 1, "GoldBar"); hud.power.custom_minimum_size = Vector2(220, 10); add_child(hud.power)
	var ctrl = _panel(Color(0, 0, 0, 0.55), Vector4(12, 8, 12, 8), 10)
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 12); g.add_theme_constant_override("v_separation", 2)
	var layout = [["WASD", "Move"], ["Shift", "Sprint"], ["J", "Pass / Tackle"], ["I", "Through ball"], ["K", "Shoot (hold) / Slide"], ["O", "Finesse shot"], ["L", "Lob / Cross"], ["E", "Skill move"], ["Q", "Switch player"], ["Esc", "Pause · H hide"]]
	if Pad.style == "ps":
		layout = [["L-stick", "Move"], ["R2", "Sprint"], ["✕", "Pass / Header"], ["△", "Through ball"], ["□", "Shoot (hold) · Slide"], ["R1+□", "Finesse shot"], ["○", "Lob / Cross · Tackle"], ["R-stick", "Skill move"], ["L1", "Switch player"], ["OPTIONS", "Pause · Touchpad hide"]]
	elif Pad.style == "xbox":
		layout = [["L-stick", "Move"], ["RT", "Sprint"], ["A", "Pass / Header"], ["Y", "Through ball"], ["X", "Shoot (hold) · Slide"], ["RB+X", "Finesse shot"], ["B", "Lob / Cross · Tackle"], ["R-stick", "Skill move"], ["LB", "Switch player"], ["Start", "Pause · Back hide"]]
	for kv in layout:
		g.add_child(UI.bold(kv[0], 12)); g.add_child(UI.label(kv[1], 12, Color("#cfd6de")))
	ctrl.add_child(g); hud.ctrl = ctrl; add_child(ctrl)
	if sim.user_side == "": ctrl.visible = false
	_layout_hud(); resized.connect(_layout_hud)

func _layout_hud() -> void:
	if hud.is_empty(): return
	hud.player.position = Vector2(22, size.y - 70)
	hud.power.position = Vector2(22, size.y - 92)
	hud.ctrl.position = Vector2(size.x - 210, size.y - 270)

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		taps[event.physical_keycode] = true
		if event.physical_keycode in [KEY_ESCAPE, KEY_P] and not sim.paused: get_viewport().set_input_as_handled(); _pause()
		if event.physical_keycode == KEY_H: help_on = not help_on; hud.ctrl.visible = help_on and sim.user_side != ""
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and not sim.paused and not done:
		get_viewport().set_input_as_handled(); _pause()

const GAME_SPEED := {"slow": 1.0, "normal": 1.2, "fast": 1.4}

func _read_input() -> void:
	var k = func(code) -> bool: return Input.is_physical_key_pressed(code) or taps.get(code, false)
	var dev = Pad.id()
	var jb = func(b) -> bool: return Input.is_joy_button_pressed(dev, b)
	var x = 0.0; var y = 0.0
	if k.call(KEY_A) or k.call(KEY_LEFT): x -= 1
	if k.call(KEY_D) or k.call(KEY_RIGHT): x += 1
	if k.call(KEY_W) or k.call(KEY_UP): y -= 1
	if k.call(KEY_S) or k.call(KEY_DOWN): y += 1
	var jx = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X); var jy = Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
	if jb.call(JOY_BUTTON_DPAD_LEFT): jx = -1
	if jb.call(JOY_BUTTON_DPAD_RIGHT): jx = 1
	if jb.call(JOY_BUTTON_DPAD_UP): jy = -1
	if jb.call(JOY_BUTTON_DPAD_DOWN): jy = 1
	if Vector2(jx, jy).length() > 0.25: x = jx; y = jy
	var v = Vector2(x, -y)
	if v.length() > 1: v = v.normalized()
	var rs = Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
	var rb: bool = jb.call(JOY_BUTTON_RIGHT_SHOULDER)
	# FIFA-style pad layout: attacking ✕ pass · △ through · □ shoot · ○ lob/cross · R1+□ finesse
	#                       defending ○ standing tackle · □ slide tackle · L1 switch · R2 sprint
	var attacking: bool = sim.user_side != "" and sim.ball.owner != null and sim.ball.owner.side == sim.user_side
	var setpiece_mine: bool = sim.state == "setpiece" and sim.sp != null and sim.teams[sim.sp.side].user
	var opp_has: bool = sim.user_side != "" and sim.ball.owner != null and sim.ball.owner.side != sim.user_side
	var defend_pad: bool = opp_has and not setpiece_mine
	var sprint_axis = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT)
	var cur = {"x": v.x, "y": v.y, "sprint": Input.is_physical_key_pressed(KEY_SHIFT) or sprint_axis > 0.4 or jb.call(JOY_BUTTON_RIGHT_STICK),
		"pass": k.call(KEY_J) or (jb.call(JOY_BUTTON_B) if defend_pad else jb.call(JOY_BUTTON_A)), "through": k.call(KEY_I) or jb.call(JOY_BUTTON_Y),
		"shoot": Input.is_physical_key_pressed(KEY_K) or (jb.call(JOY_BUTTON_X) and not rb), "lob": k.call(KEY_L) or (jb.call(JOY_BUTTON_B) and not defend_pad),
		"finesse": Input.is_physical_key_pressed(KEY_O) or (rb and jb.call(JOY_BUTTON_X)), "skill": k.call(KEY_E) or rs.length() > 0.7, "sw": k.call(KEY_Q) or jb.call(JOY_BUTTON_LEFT_SHOULDER)}
	if jb.call(JOY_BUTTON_TOUCHPAD) and not prev_in.get("touch", false): help_on = not help_on; hud.ctrl.visible = help_on and sim.user_side != ""
	cur.touch = jb.call(JOY_BUTTON_TOUCHPAD) or jb.call(JOY_BUTTON_BACK)
	var edge = {}; var rel = {}
	for key in cur:
		if typeof(cur[key]) == TYPE_BOOL: edge[key] = cur[key] and not prev_in.get(key, false)
	for key in ["shoot", "finesse"]: rel[key] = (not cur[key]) and prev_in.get(key, false)
	# quick tap of K/O (press+release inside one frame) still fires a shot
	if (taps.get(KEY_K, false) and not Input.is_physical_key_pressed(KEY_K)) or (taps.get(KEY_O, false) and not Input.is_physical_key_pressed(KEY_O)):
		var kind = "finesse" if taps.get(KEY_O, false) else "shot"
		edge.shoot = true; rel[kind] = true
		if sim.charge_kind == "": sim.charge = 0.45; sim.charge_kind = kind
	taps.clear()
	prev_in = cur
	sim.inp = cur; sim.edge = edge; sim.rel = rel

func _process(delta: float) -> void:
	if done: return
	if not sim.paused:
		_read_input()
		acc += min(delta, 0.1) * GAME_SPEED.get(Save.data.settings.get("game_speed", "normal"), 1.2)
		var step = 1.0 / 60.0
		while acc >= step and not done:
			sim.update(step); acc -= step
			sim.edge = {}; sim.rel = {}
	_update_hud()
	queue_redraw()

func _finish() -> void:
	if done: return
	done = true
	var res = sim.result()
	Sfx.crowd_off(); UI.in_match = false; UI.host.visible = true
	queue_free()
	on_done.call(res)

# ------------------------------------------------------------------ pause & subs
func _pause() -> void:
	sim.paused = true; Sfx.crowd_level(0.08); UI.in_match = false
	var body = UI.label("%s %d - %d %s" % [sim.teams.home.name, sim.score.home, sim.score.away, sim.teams.away.name], 15, UI.DIM)
	var btns = [["Resume", "resume", "Primary"]]
	if sim.user_side != "": btns.append(["Substitutions", "subs", ""])
	btns += [["Camera: " + Save.data.settings.camera, "cam", ""], ["Simulate rest", "sim", ""], ["Forfeit (0-3)" if sim.user_side != "" else "Quit match", "forfeit", "Danger"]]
	var v = await UI.modal("Paused", body, btns)
	match v:
		"subs": await _subs(); _pause(); return
		"cam":
			var cams = ["broadcast", "tele", "wide"]; Save.data.settings.camera = cams[(cams.find(Save.data.settings.camera) + 1) % 3]; Save.dirty(); _pause(); return
		"sim": _resume(); sim.simulate_rest(); return
		"forfeit":
			if sim.user_side != "":
				var u = sim.user_side
				sim.score[u] = 0; sim.score[sim.other(u)] = max(3, sim.score[sim.other(u)]); sim.goals = sim.goals.filter(func(g): return g.side != u)
			_resume(); sim.finished = true; _finish(); return
	_resume()

func _resume() -> void:
	sim.paused = false; UI.in_match = true; Sfx.crowd_level(0.3); prev_in = {}; taps.clear()

func _subs() -> void:
	var team: Dictionary = sim.teams[sim.user_side]
	var st = {"on": -1}
	var body = UI.vb(8)
	var R = {}
	R.draw = func():
		for c in body.get_children(): c.queue_free()
		body.add_child(UI.label("Substitutions used: %d/5. Select a player on the pitch, then a substitute." % sim.subs_used[sim.user_side], 13, UI.DIM))
		var cols = UI.hb(20)
		var left = UI.vb(4); left.custom_minimum_size.x = 480
		for i in team.players.size():
			var m = team.players[i]
			var b = UI.btn("%s   %s (%d)   stamina %d%%" % [m.slot_pos, m.p.name, m.p.ovr, int(m.stamina * 100)], func(): st.on = i; R.draw.call(), "Row", i == st.on or (st.on < 0 and i == 0))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if i == st.on: b.add_theme_color_override("font_color", UI.TEAL)
			left.add_child(b)
		var right = UI.vb(4); right.custom_minimum_size.x = 420
		if team.bench.is_empty(): right.add_child(UI.label("No substitutes available", 14, UI.DIM))
		for j in team.bench.size():
			var p: Dictionary = team.bench[j]
			var b = UI.btn("%s   %s (%d)" % [p.pos, p.name, p.ovr], func():
				if st.on < 0 or sim.subs_used[sim.user_side] >= 5: return
				var old = team.players[st.on]
				var nm = sim.make_mp(p, old.side, old.slot, team, team.chem.per[old.slot] if team.chem else 2)
				nm.x = old.x; nm.y = old.y; nm.face = old.face
				team.players[st.on] = nm; sim.all = sim.teams.home.players + sim.teams.away.players
				team.bench[j] = old.p
				if sim.ball.owner == old: sim.ball.owner = nm
				if sim.ctrl == old: sim.ctrl = nm
				sim.subs_used[sim.user_side] += 1; sim.msg("%s on for %s" % [Data.short_name(p.name), Data.short_name(old.p.name)], 2.5)
				st.on = -1; R.draw.call(), "Row")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.disabled = st.on < 0 or sim.subs_used[sim.user_side] >= 5
			right.add_child(b)
		cols.add_child(left); cols.add_child(right); body.add_child(cols)
	R.draw.call()
	await UI.modal("Substitutions", body, [["Done", true, "Primary"]], true)

# ------------------------------------------------------------------ HUD
var _rum = {"score": 0, "tackles": 0, "shots": 0, "state": ""}
func _rumble_feedback() -> void:
	if sim.user_side == "": return
	var me = sim.si(sim.user_side)
	var sc = sim.score.home + sim.score.away
	if sc != _rum.score: Pad.rumble(1.0, 1.0, 0.7)
	elif sim.stats.tackles[me] != _rum.tackles: Pad.rumble(0.5, 0.2, 0.15)
	elif sim.stats.shots[0] + sim.stats.shots[1] != _rum.shots: Pad.rumble(0.3, 0.6, 0.12)
	if sim.state == "fulltime" and _rum.state != "fulltime": Pad.rumble(0.6, 0.6, 0.5)
	_rum = {"score": sc, "tackles": sim.stats.tackles[me], "shots": sim.stats.shots[0] + sim.stats.shots[1], "state": sim.state}

func _update_hud() -> void:
	_rumble_feedback()
	var mins: float = min(45.0, sim.clock / sim.half_secs * 45.0) + (sim.half - 1) * 45
	var mm = int(mins); var ss = int((mins - mm) * 60)
	hud.clock.text = "GG" if sim.golden else "%02d:%02d" % [mm, ss]
	hud.score.text = "%d - %d" % [sim.score.home, sim.score.away]
	var m = sim.msgs[-1] if not sim.msgs.is_empty() else null
	hud.msg.visible = m != null
	if m: hud.msg_l.text = m.text; hud.msg.position = Vector2(size.x / 2 - hud.msg.size.x / 2, 18)
	if sim.banner != null and hud.banner.get_child_count() == 0:
		var v = UI.vb(0, [UI.head(sim.banner.big.to_upper(), 100), UI.bold(sim.banner.small, 26)])
		for c in v.get_children(): c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7)); c.add_theme_constant_override("shadow_offset_y", 6)
		v.pivot_offset = v.get_combined_minimum_size() / 2; v.scale = Vector2(1.8, 1.8); v.modulate.a = 0
		hud.banner.add_child(v)
		var tw = create_tween().set_parallel(); tw.tween_property(v, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(v, "modulate:a", 1.0, 0.3)
		hud.banner_ref = sim.banner
	elif (sim.banner == null or sim.banner != hud.get("banner_ref")) and hud.banner.get_child_count() > 0:
		for c in hud.banner.get_children(): c.queue_free()
	if sim.ctrl != null and sim.user_side != "":
		hud.player.visible = true
		hud.pname.text = "%d  %s · %s" % [sim.ctrl.p.ovr, sim.ctrl.slot_pos, sim.ctrl.p.name]
		hud.stam.value = sim.ctrl.stamina * hud.stam.max_value
	else: hud.player.visible = false
	hud.power.visible = sim.charge > 0
	hud.power.value = sim.charge

# ------------------------------------------------------------------ rendering
func cam_cfg() -> Dictionary:
	match Save.data.settings.camera:
		"tele": return {"dist": 46.0, "h": 26.0, "f": size.x * 1.05}
		"wide": return {"dist": 78.0, "h": 46.0, "f": size.x * 0.98}
	return {"dist": 60.0, "h": 34.0, "f": size.x * 1.0}

func P(x: float, y: float, z := 0.0) -> Vector3:
	var d: float = y - (cam.y - CC.dist)
	var s: float = CC.f / max(d, 1.0)
	return Vector3(size.x / 2 + (x - cam.x) * s, CC.hz + (CC.h - z) * s, s)
func V(x: float, y: float, z := 0.0) -> Vector2: var q = P(x, y, z); return Vector2(q.x, q.y)

func _quad(pts: Array, col: Color) -> void:
	var pv = PackedVector2Array()
	for p in pts: pv.append(V(p[0], p[1], p[2] if p.size() > 2 else 0.0))
	draw_colored_polygon(pv, col)

func _draw() -> void:
	if sim == null: return
	CC = cam_cfg()
	var b: Dictionary = sim.ball
	var tx: float = clamp(b.x + b.vx * 0.35, 18.0, MatchSim.PW - 18.0); var ty: float = clamp(b.y * 0.85 + MatchSim.PH / 2 * 0.15, 14.0, 54.0)
	cam.x = lerpf(cam.x, tx, 0.06); cam.y = lerpf(cam.y, ty, 0.04)
	CC.hz = size.y * 0.6 - CC.h * CC.f / CC.dist
	draw_rect(Rect2(Vector2.ZERO, size), Color("#04060a"))
	draw_rect(Rect2(0, size.y * 0.4, size.x, size.y * 0.6), Color("#0a1a10"))
	_draw_stands()
	_draw_pitch()
	_draw_goal(0.0, true); _draw_goal(MatchSim.PW, true)
	var ents = []
	for m in sim.all: ents.append([m.y, 0, m])
	ents.append([sim.ref.y, 1, null]); ents.append([b.y, 2, null])
	ents.sort_custom(func(a, c): return a[0] > c[0])
	for e in ents:
		match e[1]:
			0: _draw_player(e[2])
			1: _draw_ref()
			2: _draw_ball()
	_draw_goal(0.0, false); _draw_goal(MatchSim.PW, false)
	for L in [[-10.0, 80.0, 34.0], [MatchSim.PW + 10, 80.0, 34.0]]:
		var q = V(L[0], L[1], L[2])
		Gfx.glow(self, q, 190.0, Color(1, 1, 0.92, 0.26))
	_draw_fx()
	_draw_radar()

func _draw_stands() -> void:
	var PW = MatchSim.PW; var PH = MatchSim.PH
	_quad([[-30, 72, 0], [PW + 30, 72, 0], [PW + 30, 96, 28], [-30, 96, 28]], Color("#10141c"))
	_quad([[-5, -20, 0], [-5, PH + 6, 0], [-30, PH + 6, 22], [-30, -20, 22]], Color("#0d1118"))
	_quad([[PW + 5, -20, 0], [PW + 5, PH + 6, 0], [PW + 30, PH + 6, 22], [PW + 30, -20, 22]], Color("#0d1118"))
	var exc = 1.0 if sim.state == "goal" else sim.excitement()
	var tifo: bool = stadium.get("tifo", "none") != "none" and sim.teams.home.user
	var qp = PackedVector2Array(); var qc = PackedColorArray()
	var step: int = 2 if Save.data.settings.get("perf_mode", false) else 1
	for ci in range(0, crowd.size(), step):
		var p: Dictionary = crowd[ci]
		var q: Vector3; var col: Color = p.c
		if p.k == 0:
			var x: float = -30.0 + p.u * (PW + 60.0)
			q = P(x, 72.0 + p.v * 24.0, p.v * 28.0 + 0.4)
			if tifo and abs(x - PW / 2) < 22 and p.v > 0.3:
				var pat = 0
				match stadium.tifo:
					"stripes": pat = int((x - PW / 2 + 22) / 4) % 2
					"flames": pat = 0 if fmod(p.v * 10.0 + sin(x * 0.4) * 2.0 + 10.0, 3.0) < 1.5 else 1
					_: pat = 0 if Vector2(x - PW / 2, (p.v - 0.65) * 50.0).length() < 9 else 1
				col = tifo_cols[pat]
		else:
			var gx: float = (-5.0 - p.v * 25.0) if p.k == 1 else (PW + 5.0 + p.v * 25.0)
			q = P(gx, -20.0 + p.u * (PH + 26.0), p.v * 22.0 + 0.4)
		if q.x < -10 or q.x > size.x + 10 or q.y < -10: continue
		var jump: float = max(0.0, sin(sim.t * (3.0 + exc * 5.0) + p.ph)) * exc * q.z * 0.12
		var sz: float = max(1.2, q.z * 0.36)
		col.a = 0.55 + p.v * 0.35
		Gfx.add_quad(qp, qc, Rect2(q.x, q.y - jump, sz * step, sz * 1.25), col)
	Gfx.flush_quads(self, qp, qc)
	var boards = [[[-4, 71, 0], [PW + 4, 71, 0], [PW + 4, 71, 1], [-4, 71, 1]], [[-3, -2, 0], [-3, PH + 2, 0], [-3, PH + 2, 1], [-3, -2, 1]], [[PW + 3, -2, 0], [PW + 3, PH + 2, 0], [PW + 3, PH + 2, 1], [PW + 3, -2, 1]]]
	for i in boards.size():
		_quad(boards[i], Color("#0c2733"))
		var ph = fmod(sim.t * 0.12 + i * 0.3, 1.0)
		var a: Array = boards[i][0]; var c: Array = boards[i][1]
		var mx: float = lerpf(a[0], c[0], ph); var my: float = lerpf(a[1], c[1], ph)
		var hl = Color("#ffd23f") if sim.state == "goal" else UI.TEAL
		var w: float = 3.0 if i == 0 else 2.0
		_quad([[mx - w * (1 if i == 0 else 0), my - w * (0 if i == 0 else 1), 0], [mx + w * (1 if i == 0 else 0), my + w * (0 if i == 0 else 1), 0], [mx + w * (1 if i == 0 else 0), my + w * (0 if i == 0 else 1), 1], [mx - w * (1 if i == 0 else 0), my - w * (0 if i == 0 else 1), 1]], hl)
	var nq = P(PW / 2, 71, 0.5)
	Gfx.text_c(self, UI.font_head, nq.x, nq.y + nq.z * 0.3, (stadium.name if sim.teams.home.user else "PRIME FOOTBALL 27").to_upper(), int(max(8.0, nq.z * 0.8)), Color(1, 1, 1, 0.85))

func _draw_pitch() -> void:
	var PW = MatchSim.PW; var PH = MatchSim.PH
	var theme: String = stadium.get("theme", "classic") if sim.teams.home.user else "classic"
	var N = 18
	for i in N:
		var x0 = -4.0 + i * (PW + 8.0) / N; var x1 = x0 + (PW + 8.0) / N
		if theme == "checker":
			for j in 6:
				var y0 = -4.0 + j * (PH + 8.0) / 6; var y1 = y0 + (PH + 8.0) / 6
				_quad([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], Color("#1f7a3c") if (i + j) % 2 else Color("#1b6d35"))
		else: _quad([[x0, -4], [x1, -4], [x1, PH + 4], [x0, PH + 4]], (Color("#1f7a3c") if theme == "gold" else Color("#1e753a")) if i % 2 else (Color("#1a6833") if theme == "gold" else Color("#1b6b35")))
	var lc = Color(1, 1, 1, 0.75)
	_line([[0, 0], [PW, 0], [PW, PH], [0, PH], [0, 0]], lc); _line([[PW / 2, 0], [PW / 2, PH]], lc)
	_arc(PW / 2, PH / 2, 9.15, 0, TAU, lc)
	for gx in [0.0, PW]:
		var d = 1.0 if gx == 0.0 else -1.0
		_line([[gx, PH / 2 - 20.16], [gx + d * 16.5, PH / 2 - 20.16], [gx + d * 16.5, PH / 2 + 20.16], [gx, PH / 2 + 20.16]], lc)
		_line([[gx, PH / 2 - 9.16], [gx + d * 5.5, PH / 2 - 9.16], [gx + d * 5.5, PH / 2 + 9.16], [gx, PH / 2 + 9.16]], lc)
		var a = acos(5.5 / 9.15)
		if gx == 0.0: _arc(11, PH / 2, 9.15, -a, a, lc)
		else: _arc(PW - 11, PH / 2, 9.15, PI - a, PI + a, lc)
		draw_circle(V(gx + d * 11, PH / 2), 2, Color.WHITE)
	draw_circle(V(PW / 2, PH / 2), 2, Color.WHITE)
	for c in [[0.0, 0.0], [PW, 0.0], [0.0, PH], [PW, PH]]:
		var a = V(c[0], c[1]); var t = P(c[0], c[1], 1.6)
		draw_line(a, Vector2(t.x, t.y), Color("#dddddd"), 1.5)
		draw_rect(Rect2(t.x, t.y, max(3.0, t.z * 0.5), max(2.0, t.z * 0.35)), Color("#ffd23f"))

func _line(pts: Array, c: Color) -> void:
	var pv = PackedVector2Array()
	for p in pts: pv.append(V(p[0], p[1]))
	draw_polyline(pv, c, 1.6, true)
func _arc(cx: float, cy: float, r: float, a0: float, a1: float, c: Color) -> void:
	var pts = []
	for i in 29: var a = a0 + (a1 - a0) * i / 28.0; pts.append([cx + cos(a) * r, cy + sin(a) * r])
	_line(pts, c)

func _draw_goal(gx: float, back: bool) -> void:
	var d = -1.0 if gx == 0.0 else 1.0; var depth = 2.0
	var GY0 = MatchSim.GY0; var GY1 = MatchSim.GY1; var GH = MatchSim.GOAL_H
	if back:
		var nc = Color(1, 1, 1, 0.28)
		for i in 11:
			var y = GY0 + i * MatchSim.GOAL_W / 10.0
			draw_polyline(PackedVector2Array([V(gx, y, GH), V(gx + d * depth, y, GH * 0.8), V(gx + d * depth, y, 0)]), nc, 0.8)
		for j in 6:
			var z = j * GH * 0.8 / 5.0
			draw_line(V(gx + d * depth, GY0, z), V(gx + d * depth, GY1, z), nc, 0.8)
		_quad([[gx, GY0, 0], [gx + d * depth, GY0, 0], [gx + d * depth, GY1, 0], [gx, GY1, 0]], Color(0, 0, 0, 0.18))
		_post(gx, GY1)
	else:
		_post(gx, GY0)
		var a = P(gx, GY0, GH)
		draw_line(Vector2(a.x, a.y), V(gx, GY1, GH), Color("#f5f5f5"), max(2.0, a.z * 0.13))
func _post(x: float, y: float) -> void:
	var a = P(x, y, 0); draw_line(Vector2(a.x, a.y), V(x, y, MatchSim.GOAL_H), Color("#f5f5f5"), max(2.0, a.z * 0.13))

func _draw_player(m) -> void:
	var base = P(m.x, m.y, 0)
	if base.x < -60 or base.x > size.x + 60: return
	var sc = base.z; var hgt: float = sc * (m.p.height / 100.0); var w = hgt * 0.27
	var kit = ({"c1": "#2bd96b", "c2": "#0d3b1f"} if m.side == "home" else {"c1": "#ffcc00", "c2": "#3a2c00"}) if m.gk else m.team.kit
	var c1 = Color(kit.c1); var c2 = Color(kit.c2)
	var b = Vector2(base.x, base.y)
	Gfx.ellipse(self, b + Vector2(w * 0.3, 0), w * 1.05, w * 0.3, Color(0, 0, 0, 0.32), 14)
	if sim.ctrl == m and sim.user_side != "":
		Gfx.ellipse_line(self, b, w * 1.5, w * 0.48, UI.TEAL if Color(m.team.kit.c1).get_luminance() > 0.85 else Color.WHITE, 2.2, 24)
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -hgt - 5), b + Vector2(-6, -hgt - 14), b + Vector2(6, -hgt - 14)]), UI.TEAL)
		var nm = Data.short_name(m.p.name); var fs = int(max(11.0, sc * 0.42))
		Gfx.text_c(self, UI.font_bold, b.x + 1, b.y - hgt - 17, nm, fs, Color(0, 0, 0, 0.7))
		Gfx.text_c(self, UI.font_bold, b.x, b.y - hgt - 18, nm, fs, Color.WHITE)
	var lying: bool = m.sliding > 0 or (m.dive != null and abs(m.dive.vy) > 1)
	var rot = 0.0
	if lying: rot = (sign(m.dive.vy) * 1.25) if m.dive != null else ((1.0 if cos(m.face) >= 0 else -1.0) * 1.1)
	draw_set_transform(b + (Vector2(0, -hgt * 0.25) if m.dive != null and lying else Vector2.ZERO), rot, Vector2.ONE)
	var sw: float = sin(m.ph * 2.3) * min(1.0, Vector2(m.vx, m.vy).length() / 3.0)
	var lw: float = max(1.4, w * 0.3)
	draw_line(Vector2(-w * 0.18, -hgt * 0.47), Vector2(-w * 0.18 + sw * w * 0.75, 0), Color("#141414"), lw)
	draw_line(Vector2(w * 0.18, -hgt * 0.47), Vector2(w * 0.18 - sw * w * 0.75, 0), Color("#141414"), lw)
	draw_line(Vector2(-w * 0.18 + sw * w * 0.45, -hgt * 0.2), Vector2(-w * 0.18 + sw * w * 0.7, -hgt * 0.04), c2, max(1.4, w * 0.32))
	draw_line(Vector2(w * 0.18 - sw * w * 0.45, -hgt * 0.2), Vector2(w * 0.18 - sw * w * 0.7, -hgt * 0.04), c2, max(1.4, w * 0.32))
	draw_rect(Rect2(-w * 0.52, -hgt * 0.56, w * 1.04, hgt * 0.13), c2)
	draw_rect(Rect2(-w * 0.56, -hgt * 0.86, w * 1.12, hgt * 0.33), c1)
	draw_rect(Rect2(-w * 0.56, -hgt * 0.86, w * 1.12, hgt * 0.33), Color(0, 0, 0, 0.25), false, 1.0)
	if hgt > 26: Gfx.text_c(self, UI.font_head, 0, -hgt * 0.64, str(m.slot + 1), int(hgt * 0.16), c2)
	var arm_up = -0.5 if m.gk and m.dive != null else 0.0
	draw_line(Vector2(-w * 0.5, -hgt * 0.82), Vector2(-w * 0.62 - sw * w * 0.35, -hgt * (0.6 + arm_up)), c1, max(1.3, w * 0.25))
	draw_line(Vector2(w * 0.5, -hgt * 0.82), Vector2(w * 0.62 + sw * w * 0.35, -hgt * (0.6 + arm_up)), c1, max(1.3, w * 0.25))
	draw_circle(Vector2(0, -hgt * 0.93), w * 0.33, Color(Data.SKINS[int(m.p.face.skin)]))
	if int(m.p.face.hair) != 5: draw_arc(Vector2(0, -hgt * 0.95), w * 0.3, PI, TAU, 10, Color(Data.HAIRC[int(m.p.face.hairC)]), w * 0.18)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if m.label_t > 0 and m.label != "":
		Gfx.text_c(self, UI.font_bold, b.x, b.y - hgt - (32 if sim.ctrl == m else 8), m.label, int(max(10.0, sc * 0.38)), Color(1, 0.82, 0.25, min(1.0, m.label_t * 2)))

func _draw_ref() -> void:
	var r: Dictionary = sim.ref; var base = P(r.x, r.y, 0); var hgt = base.z * 1.8; var w = hgt * 0.27
	var b = Vector2(base.x, base.y)
	Gfx.ellipse(self, b, w, w * 0.3, Color(0, 0, 0, 0.3), 12)
	var sw: float = sin(r.ph * 2.3) * min(1.0, Vector2(r.vx, r.vy).length() / 3.0)
	draw_line(b + Vector2(-w * 0.18, -hgt * 0.47), b + Vector2(-w * 0.18 + sw * w * 0.7, 0), Color("#111111"), max(1.4, w * 0.3))
	draw_line(b + Vector2(w * 0.18, -hgt * 0.47), b + Vector2(w * 0.18 - sw * w * 0.7, 0), Color("#111111"), max(1.4, w * 0.3))
	draw_rect(Rect2(b + Vector2(-w * 0.5, -hgt * 0.56), Vector2(w, hgt * 0.13)), Color("#111111"))
	draw_rect(Rect2(b + Vector2(-w * 0.55, -hgt * 0.86), Vector2(w * 1.1, hgt * 0.33)), Color("#e6ff3f"))
	draw_circle(b + Vector2(0, -hgt * 0.93), w * 0.32, Color("#b07a52"))

func _draw_ball() -> void:
	var b: Dictionary = sim.ball
	var g = P(b.x, b.y, 0); var q = P(b.x, b.y, b.z + 0.11)
	var r: float = max(2.2, q.z * 0.17)
	Gfx.ellipse(self, Vector2(g.x, g.y), r * 1.1, r * 0.4, Color(0, 0, 0, 0.4 - min(0.3, b.z * 0.05)), 12)
	if b.shot != null and Vector2(b.vx, b.vy).length() > 15:
		draw_line(V(b.x - b.vx * 0.05, b.y - b.vy * 0.05, b.z), Vector2(q.x, q.y), Color(1, 1, 1, 0.35), r)
	draw_circle(Vector2(q.x, q.y), r, Color.WHITE)
	var rot: float = (b.x + b.y) * 1.3
	draw_circle(Vector2(q.x, q.y) + Vector2(cos(rot), sin(rot)) * r * 0.4, r * 0.35, Color("#222222"))
	draw_arc(Vector2(q.x, q.y), r, 0, TAU, 16, Color(0, 0, 0, 0.35), 1)
	if sim.state == "setpiece" and sim.sp != null and sim.sp.get("aim") != null and sim.teams[sim.sp.side].user:
		var a = V(b.x + sim.sp.aim.x * 6, b.y + sim.sp.aim.y * 6)
		draw_dashed_line(Vector2(g.x, g.y), a, Color(0.25, 0.88, 0.77, 0.9), 3, 8)

func _draw_fx() -> void:
	for f in sim.fx:
		if f.type != "confetti": continue
		if f.p == null:
			f.p = []
			for i in 160: f.p.append({"x": randf() * size.x, "y": -randf() * size.y * 0.5, "vy": randf_range(60, 180), "vx": randf_range(-40, 40), "c": [Color("#ffd23f"), UI.TEAL, Color("#ff4fa3"), Color.WHITE, Color("#3ea6ff")][randi() % 5], "r": randf() * 6})
		for p in f.p:
			p.y += p.vy / 60.0; p.x += p.vx / 60.0; p.r += 0.1
			draw_set_transform(Vector2(p.x, p.y), p.r, Vector2.ONE); draw_rect(Rect2(-4, -2, 8, 4), p.c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_radar() -> void:
	var RW = 168.0; var RH = 110.0
	var o = Vector2(size.x / 2 - RW / 2, size.y - RH - 18)
	draw_rect(Rect2(o, Vector2(RW, RH)), Color(0.08, 0.24, 0.12, 0.6))
	draw_rect(Rect2(o + Vector2(4, 4), Vector2(RW - 8, RH - 8)), Color(1, 1, 1, 0.45), false, 1)
	draw_line(o + Vector2(RW / 2, 4), o + Vector2(RW / 2, RH - 4), Color(1, 1, 1, 0.45), 1)
	var S = func(x, y): return o + Vector2(4 + x / MatchSim.PW * (RW - 8), RH - 4 - y / MatchSim.PH * (RH - 8))
	for m in sim.all:
		var is_c: bool = m == sim.ctrl
		draw_circle(S.call(m.x, m.y), 3.6 if is_c else 2.6, UI.TEAL if is_c else Color(m.team.kit.c1))
		draw_arc(S.call(m.x, m.y), 3.6 if is_c else 2.6, 0, TAU, 10, Color(0, 0, 0, 0.6), 0.8)
	draw_circle(S.call(sim.ball.x, sim.ball.y), 2.4, Color.WHITE)
