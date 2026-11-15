extends RefCounted
## Division Rivals screen (FC-style): division badge · ranks I–XII with checkpoints · next division,
## 15-minute rewards panel with reward levels, checkpoint panel, Play Rivals.

const ORANGE := Color("#ff7a1a")
const BLUE := Color("#2fb6ff")
const GREENC := Color("#3fe0a0")

class RivalsBG extends Control:
	var col = Color(1, 0.48, 0.1)
	func _draw() -> void:
		var W = size.x; var H = size.y
		draw_rect(Rect2(0, 0, W, H), Color("#0b0d12"))
		for i in 20: draw_rect(Rect2(W * i / 20.0, 0, W / 20.0 + 1, H), Color(0.06 + 0.03 * i / 20.0, 0.05, 0.06, 1.0))
		var cx = W * 0.62; var cy = H * 0.32
		for k in 3:
			var a = 0.22 - k * 0.06
			var s = 1.0 + k * 0.35
			draw_polyline(PackedVector2Array([Vector2(cx - 180 * s, cy + 160 * s), Vector2(cx - 40 * s, cy - 140 * s), Vector2(cx + 120 * s, cy - 140 * s), Vector2(cx + 150 * s, cy - 60 * s), Vector2(cx + 20 * s, cy + 20 * s), Vector2(cx + 170 * s, cy + 160 * s)]), Color(col, a), 6.0 - k * 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(W * 0.82, 0), Vector2(W * 0.96, H * 0.45), Vector2(W, H * 0.4)]), Color(col, 0.12), 8.0, true)
		draw_rect(Rect2(0, 0, W, H * 0.5), Color(col, 0.035))

class StepShield extends Button:
	var label_txt = ""; var state = "locked"; var cp = false; var cp_done = false; var reward_dot = false
	var col = Color("#d0641a")
	func _ready() -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; custom_minimum_size = Vector2(44, 52)
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: add_theme_stylebox_override(s, StyleBoxEmpty.new())
		focus_entered.connect(func(): queue_redraw(); Sfx.play("move")); focus_exited.connect(queue_redraw)
		mouse_entered.connect(func(): if UI.mouse_recent(): grab_focus())
	func _draw() -> void:
		var r = Rect2(Vector2(5, 6), size - Vector2(10, 12))
		var sh = Gfx.shield(r)
		if has_focus(): draw_colored_polygon(Gfx.shield(r.grow(4)), Color(1, 1, 1, 0.55))
		var fill = Color("#1c1f26") if state == "locked" else (col.darkened(0.15) if state == "done" else Color("#2a2f3a"))
		var edge = Color("#6f7682") if state == "locked" else (col.lightened(0.35) if state == "done" else Color.WHITE)
		if state == "current": fill = col.darkened(0.72); edge = col.lightened(0.15)
		draw_colored_polygon(sh, fill)
		var o = sh.duplicate(); o.append(sh[0]); draw_polyline(o, edge, 2.0, true)
		Gfx.text_c(self, UI.font_bold, r.get_center().x, r.get_center().y + 5, label_txt, 13, Color.WHITE)
		if cp:
			var c = Vector2(r.end.x - 2, r.position.y + 3)
			draw_circle(c, 7, Color("#0b0d12")); draw_circle(c, 6, Color("#3fe0a0") if cp_done else Color("#6f7682"))
			draw_circle(c, 2.5, Color("#0b0d12"))
		if reward_dot:
			var c2 = Vector2(r.end.x - 2, r.position.y + 3); draw_circle(c2, 6, Color("#ffb21a"))

class DivBadge extends Control:
	var txt = ""; var current = true; var col = Color("#ff7a1a")
	func _draw() -> void:
		var r = Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var pts = PackedVector2Array()
		for i in 8:
			var a = -PI / 2 + i * TAU / 8.0 + PI / 8.0
			pts.append(r.get_center() + Vector2(cos(a), sin(a)) * r.size.x * 0.5)
		if current:
			var g = pts.duplicate()
			for i in g.size(): g[i] = r.get_center() + (g[i] - r.get_center()) * 1.12
			draw_colored_polygon(g, Color(col, 0.22))
		draw_colored_polygon(pts, col.darkened(0.7) if current else col.darkened(0.82))
		var o = pts.duplicate(); o.append(pts[0]); draw_polyline(o, col if current else col.darkened(0.25), 3.0, true)
		Gfx.text_c(self, UI.font_head, r.get_center().x, r.get_center().y + r.size.y * 0.18, txt, int(r.size.y * 0.5), Color.WHITE)

func _mmss(sec: float) -> String:
	var s = int(sec); return "%d:%02d" % [s / 60, s % 60]

func s_rivals(p) -> Dictionary:
	if UI.mobile: return _rivals_mobile()
	Rivals.tick()
	var R = Rivals.st(); var d: int = Rivals.div(); var step: int = int(R.step)
	var page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var DC: Color = Rivals.div_color(d)
	var bgc = RivalsBG.new(); bgc.col = DC; bgc.set_anchors_preset(Control.PRESET_FULL_RECT); page.add_child(bgc)
	var mg = MarginContainer.new(); mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for kv in [["left", 52], ["right", 52], ["top", 20], ["bottom", 14]]: mg.add_theme_constant_override("margin_" + kv[0], kv[1])
	page.add_child(mg)
	var v = UI.vb(12); mg.add_child(v)
	v.add_child(UI.hb(14, [UI.icon("badge", Save.data.profile.badge, Vector2(44, 48)), UI.label("Play", 20, UI.DIM), UI.bold("Rivals", 22), UI._sepline(), UI.btn("Champions", func(): UI.go("champions"), "Small"), UI.spacer(), UI.currency_bar()]))
	var cd = UI.bold("", 17, DC)
	var upd_cd = func(): cd.text = "⏱ " + _mmss(Rivals.cycle_left())
	upd_cd.call()
	var qp = UI.bold("★ %s/%s" % [Sys.fmt(Champs.st().qp), Sys.fmt(Champs.QP_NEED)], 17, Color("#e8c46a"))
	v.add_child(UI.vb(4, [UI.hb(14, [UI.head("DIVISION RIVALS", 42), UI.head("· " + Rivals.div_name(d).to_upper(), 42, DC)]), UI.hb(14, [UI.label("Next rewards in", 16), cd, UI.label("Champions Qual. Points", 16, UI.DIM), qp]),
		UI.label("Play Rivals matches to earn points and unlock rewards every 15 minutes. The higher your division, the better the rewards. Points also qualify you for Champions.", 15, UI.DIM)]))
	# ---- ladder: current division badge · I..XII · next division
	var lad = HBoxContainer.new(); lad.add_theme_constant_override("separation", 0); lad.alignment = BoxContainer.ALIGNMENT_CENTER
	var cur_b = DivBadge.new(); cur_b.txt = "E" if d == 1 else str(d); cur_b.col = DC; cur_b.custom_minimum_size = Vector2(78, 78); lad.add_child(cur_b)
	var marker = HBoxContainer.new(); marker.add_theme_constant_override("separation", 0); marker.alignment = BoxContainer.ALIGNMENT_CENTER
	var m0 = Control.new(); m0.custom_minimum_size.x = 78; marker.add_child(m0)
	for i in Rivals.STEPS:
		var con = ColorRect.new(); con.custom_minimum_size = Vector2(28, 4); con.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		con.color = DC if i < step else Color(DC, 0.3); lad.add_child(con)
		var sh = StepShield.new(); sh.label_txt = Rivals.ROMAN[i]; sh.col = DC
		sh.state = "done" if i < step else ("current" if i == step else "locked")
		sh.cp = Rivals.CHECKPOINTS.has(i + 1); sh.cp_done = int(R.cp) >= i + 1
		sh.reward_dot = i == Rivals.STEPS - 1
		sh.pressed.connect(func(): _preview(d))
		lad.add_child(sh)
		var ms = Control.new(); ms.custom_minimum_size.x = 28; marker.add_child(ms)
		var mk = Label.new(); mk.custom_minimum_size.x = 44; mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mk.text = "▼" if i == max(0, min(step, Rivals.STEPS) - 1) else ""; mk.add_theme_color_override("font_color", GREENC); mk.add_theme_font_size_override("font_size", 20)
		marker.add_child(mk)
	var con2 = ColorRect.new(); con2.custom_minimum_size = Vector2(28, 4); con2.size_flags_vertical = Control.SIZE_SHRINK_CENTER; con2.color = Color(DC, 0.3); lad.add_child(con2)
	var nxt = DivBadge.new(); nxt.txt = ("E" if d - 1 == 1 else str(d - 1)) if d > 1 else "★"; nxt.current = false; nxt.col = Rivals.div_color(max(1, d - 1)); nxt.custom_minimum_size = Vector2(66, 66); lad.add_child(nxt)
	var m_end = Control.new(); m_end.custom_minimum_size.x = 28 + 66; marker.add_child(m_end)
	v.add_child(UI.vb(0, [marker, lad]))
	var sub = "%s · %s%s%s" % [Rivals.div_name(d), ("Rank %s of XII · next: %s" % [Rivals.ROMAN[step - 1], Rivals.ROMAN[step] if step < 12 else "promotion"]) if step > 0 else "Rank 0 · win to reach I", "  ·  Safe division (no relegation)" if Rivals.safe(d) else "", "  ·  Win streak %d (wins give +2 ranks)" % R.streak if int(R.streak) >= 3 else ("  ·  Win streak %d" % R.streak if int(R.streak) > 0 else "")]
	var sl = UI.label(sub, 15, UI.DIM); sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sl)
	# ---- bottom
	var cyc_pts: int = int(R.cycle.pts)
	var S = {"lvl": clamp(Rivals.level_for(cyc_pts) + 1, 1, 3)}
	var rw_title = UI.label("", 15); var rw_lvl = UI.bold("", 17); var rw_pts = UI.head("", 28, BLUE); var rw_txt = UI.label("", 14)
	var dots = UI.label("", 16, UI.DIM)
	var art: Icon
	var show_lvl = func(l: int):
		S.lvl = l
		var need = Rivals.LEVEL_PTS[l - 1]
		rw_title.text = ("Reward level %d unlocked for this window" % l) if cyc_pts >= need else "Earn %d more point%s in this window to get this reward" % [need - cyc_pts, "" if need - cyc_pts == 1 else "s"]
		rw_lvl.text = "Reward level %d" % l
		rw_pts.text = "%d/%d pts" % [min(cyc_pts, need), need]
		rw_pts.add_theme_color_override("font_color", UI.GREEN if cyc_pts >= need else BLUE)
		rw_txt.text = Rivals.reward_text(Rivals.reward(d, l))
		dots.text = "  ".join(range(1, 4).map(func(k): return "●" if k == l else "○"))
		var rr = Rivals.reward(d, l)
		if S.has("art"): S.art.arg = rr.packs[0] if rr.has("packs") else rr.get("pack", "gold"); S.art.queue_redraw()
	art = UI.icon("pack", "premium", Vector2(96, 134)); art.animate = false; S.art = art
	show_lvl.call(S.lvl)
	var lvl_nav = UI.hb(6, [UI.btn("◀", func(): show_lvl.call(max(1, S.lvl - 1)), "Small"), dots, UI.btn("▶", func(): show_lvl.call(min(3, S.lvl + 1)), "Small")])
	var rp = UI.panel(UI.vb(8, [UI.bold("Rivals Rewards · every 15 minutes", 18), rw_title, UI.hb(16, [art, UI.vb(4, [rw_lvl, rw_pts, rw_txt])]), lvl_nav]))
	rp.custom_minimum_size = Vector2(470, 280)
	var cpp = UI.vb(10)
	var cp_row = func(title: String, desc: String, val: String, ok: bool) -> Control:
		return UI.panel(UI.hb(12, [UI.vb(2, [UI.bold(("◉ " if ok else "○ ") + title, 16, GREENC if ok else UI.DIM), UI.wrapl(UI.label(desc, 13, UI.DIM), 330)]), UI.spacer(), UI.head(val, 26, GREENC if ok else UI.DIM)]), "Glass")
	cpp.add_child(cp_row.call("Division checkpoint", "Saves your rank in this division against losses.", "%d/2" % (1 if int(R.cp) >= 4 else 0) if int(R.cp) < 8 else "2/2", int(R.cp) > 0))
	cpp.add_child(cp_row.call("Safe division" if Rivals.safe(d) else "Relegation zone", "You can't be relegated from this division." if Rivals.safe(d) else "Losing at rank 0 without a checkpoint drops you a division.", "✓" if Rivals.safe(d) else "!", Rivals.safe(d)))
	cpp.add_child(cp_row.call("This window", "Win 3 pts · Draw 1 pt · Levels at 1 / 3 / 6 pts", "%d pts" % cyc_pts, cyc_pts > 0))
	cpp.custom_minimum_size.x = 470
	var left = UI.vb(10)
	var un: Array = R.unclaimed
	if not un.is_empty():
		var cl = UI.btn("Claim Rivals Rewards (%d)" % un.size(), func():
			var n = Rivals.claim_all(); Sfx.play("bigreveal"); UI.toast("Claimed %d Rivals reward%s" % [n, "" if n == 1 else "s"], "good"); UI.replace("rivals"), "Primary", true)
		cl.custom_minimum_size = Vector2(300, 50); left.add_child(cl)
	var opp_l = UI.label("Next opponent ~%d rated · AI %s" % [int(Sys.rivals_strength(d)), Sys.ai_label(Sys.rivals_ai(d))], 13, UI.DIM)
	var play = UI.btn("%s  Play Rivals" % Pad.glyph("A"), func(): play_match(), "Primary" if un.is_empty() else "", un.is_empty())
	play.custom_minimum_size = Vector2(300, 54)
	left.add_child(play); left.add_child(opp_l)
	left.add_child(UI.label("Record: %dW · %dD · %dL  ·  Best: %s" % [R.wins, R.draws, R.losses, Rivals.div_name(int(R.best))], 13, UI.DIM))
	var bottom = UI.hb(20, [left, UI.spacer(), rp, cpp]); bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(UI.vspacer()); v.add_child(bottom)
	var g = func(ps: String, xb: String, kb: String) -> String: return ps if Pad.style == "ps" else (xb if Pad.style == "xbox" else kb)
	v.add_child(UI.hb(22, [UI._key_hint(g.call("○", "B", "Esc"), "Back"), UI._key_hint(g.call("□", "X", "R"), "Preview Rewards"), UI._key_hint(g.call("◀ L ▶", "◀ L ▶", "◀ ▶"), "Navigate"), UI._key_hint(g.call("L2 / R2", "LT / RT", "Z / C"), "Reward levels")]))
	UI.keyhook(page, {"j%d" % JOY_BUTTON_X: func(): _preview(d), "k%d" % KEY_R: func(): _preview(d), "k%d" % KEY_Z: func(): show_lvl.call(max(1, S.lvl - 1)), "k%d" % KEY_C: func(): show_lvl.call(min(3, S.lvl + 1))})
	# L2 / R2 cycle the reward levels
	var segd = {"items": [["1", "1"], ["2", "2"], ["3", "3"]], "current": str(S.lvl)}
	segd.cb = func(x): show_lvl.call(int(x)); segd.current = str(x)
	UI._segs.append(segd)
	var t = Timer.new(); t.wait_time = 1.0; t.autostart = true; page.add_child(t)
	var last_un = {"n": un.size()}
	t.timeout.connect(func():
		upd_cd.call()
		if Rivals.st().unclaimed.size() != last_un.n and UI.modals.is_empty(): UI.replace("rivals"))
	return {"node": page, "bg": "off", "back": _back_or_play}

func _preview(d: int) -> void:
	var g = GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 20); g.add_theme_constant_override("v_separation", 8)
	for hdr in ["Division", "Level 1 (1 pt)", "Level 2 (3 pts)", "Level 3 (6 pts)"]: g.add_child(UI.caps(hdr, 10))
	for dd in range(1, 11):
		g.add_child(UI.bold(("▶ " if dd == d else "") + Rivals.div_name(dd), 14, Rivals.div_color(dd)))
		for l in [1, 2, 3]: g.add_child(UI.label(Rivals.reward_text(Rivals.reward(dd, l)).replace("\n", " · "), 12, UI.TEXT if dd == d else UI.DIM))
	await UI.modal("Rivals Rewards", UI.vb(10, [UI.label("Rewards are given every 15 minutes for the points you earn in that window (win 3 · draw 1). Checkpoints at IV and VIII protect your rank; reach XII to be promoted.", 14, UI.DIM), g]), [["Close", null, "Primary"]], true)

func play_match() -> void:
	if not UI.modules[2].require_squad(): return
	var d = Rivals.div()
	var ut = Sys.user_team()
	var name: String = Sys.pick(["Ace", "Pro", "King", "Volt", "Nova", "Zed", "Kai", "Rex"]) + Sys.pick(["_FC", "Gaming", "99", "Utd", "XI", "_27"])
	var target: int = int(round(Sys.rivals_strength(d)))
	var opp = Sys.ai_team(name, target, false)   # Extreme Rivals scale by division (no flat 92+ floor)
	if Sys.extreme(): Sys.boost_to(opp, target)
	Sys.league3_check(ut)
	UI.run_match({"home": ut, "away": opp, "user_side": "home", "difficulty": Sys.rivals_difficulty(d), "ai": Sys.rivals_ai(d), "elite": true, "half_len": int(Save.data.settings.half_len), "mode": "rivals", "title": "Division Rivals · " + Rivals.div_name(d)}, func(res):
		var r = Sys.record_ut_match(res); var out = Rivals.record(r)
		Sys.log_match(res, "Rivals", r)
		UI.show_results(res, "Division Rivals", "+%s coins%s" % [Sys.fmt(out.coins), (" · " + out.msg) if out.msg != "" else ""], func(): UI.replace("rivals")))

func _back_or_play() -> void:
	if UI.stack.is_empty(): UI.reset("play")
	else: UI.back()


# ------------------------------------------------------------------ PHONE LAYOUT (companion)
class RankStrip extends Control:
	## 12 rank segments, checkpoints marked, filled up to the current rank
	var step = 0; var col = Color.WHITE; var cp = 0
	func _init() -> void: custom_minimum_size = Vector2(0, 30)
	func _draw() -> void:
		var n = Rivals.STEPS; var gap = 4.0; var w = (size.x - gap * (n - 1)) / n
		for i in n:
			var r = Rect2(i * (w + gap), 8, w, 12)
			draw_rect(r, col if i < step else Color(1, 1, 1, 0.12))
			if Rivals.CHECKPOINTS.has(i + 1):
				draw_circle(Vector2(r.end.x, 4), 4, Color("#3fe0a0") if cp >= i + 1 else Color("#6f7682"))
		var fnt = UI.font_bold
		for k in [0, 3, 7, 11]:
			var x = k * (w + gap) + w / 2
			var t = Rivals.ROMAN[k]; var tw = fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(fnt, Vector2(x - tw / 2, 30), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.5))

func _rivals_mobile() -> Dictionary:
	Rivals.tick()
	var R = Rivals.st(); var d: int = Rivals.div(); var step: int = int(R.step)
	var DC: Color = Rivals.div_color(d)
	var f = UI.sub_shell("Division Rivals", "Play")
	var b: VBoxContainer = f.body
	# division hero
	var badge = DivBadge.new(); badge.txt = "E" if d == 1 else str(d); badge.col = DC; badge.custom_minimum_size = Vector2(78, 78)
	var rank_txt = ("Rank %s of XII" % Rivals.ROMAN[step - 1]) if step > 0 else "Rank 0 · win to reach I"
	var hero = UI.vb(10, [UI.hb(12, [badge, UI.vb(2, [UI.head(Rivals.div_name(d).to_upper(), 28, DC), UI.label(rank_txt, 14), UI.label("Safe division — no relegation" if Rivals.safe(d) else "Relegation possible at rank 0", 12, UI.GREEN if Rivals.safe(d) else Color("#ff9a3c"))])])])
	var strip = RankStrip.new(); strip.step = step; strip.col = DC; strip.cp = int(R.cp)
	hero.add_child(strip)
	b.add_child(UI.m_card(hero, DC))
	b.add_child(UI.hb(8, [UI.m_chip("%d" % int(R.streak), "Win streak", UI.GREEN if int(R.streak) >= 3 else UI.TEXT), UI.m_chip("%d-%d-%d" % [R.wins, R.draws, R.losses], "W-D-L"), UI.m_chip(("E" if int(R.best) == 1 else str(R.best)), "Best div")]))
	# claim + play
	var un: Array = R.unclaimed
	if not un.is_empty():
		b.add_child(UI.m_cta("Claim Rivals Rewards (%d)" % un.size(), func():
			var n = Rivals.claim_all(); Sfx.play("bigreveal"); UI.toast("Claimed %d Rivals reward%s" % [n, "" if n == 1 else "s"], "good"); UI.replace("rivals")))
	b.add_child(UI.m_cta("Simulate Rivals Match", func(): play_match(), "Primary" if un.is_empty() else ""))
	b.add_child(UI.label("Next opponent ~%d rated · AI %s · Win = 3 pts, draw = 1" % [int(Sys.rivals_strength(d)), Sys.ai_label(Sys.rivals_ai(d))], 12, UI.DIM))
	# 15-minute rewards
	var cyc_pts: int = int(R.cycle.pts)
	var cd = UI.bold("", 16, DC)
	var upd = func(): if is_instance_valid(cd): cd.text = "⏱ " + _mmss(Rivals.cycle_left())
	upd.call()
	var rw = UI.vb(8, [UI.hb(8, [UI.bold("Rewards every 15 minutes", 16), UI.spacer(), cd]), UI.label("This window: %d pts" % cyc_pts, 13, UI.DIM)])
	for l in [1, 2, 3]:
		var need: int = Rivals.LEVEL_PTS[l - 1]; var got: bool = cyc_pts >= need
		var rr = Rivals.reward(d, l)
		var art = UI.icon("pack", rr.packs[0] if rr.has("packs") else rr.get("pack", "gold"), Vector2(40, 56)); art.animate = false
		var t = UI.vb(1, [UI.bold("Level %d · %d pt%s" % [l, need, "" if need == 1 else "s"], 14, UI.GREEN if got else UI.TEXT), UI.label(Rivals.reward_text(rr), 12, UI.DIM)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.get_child(1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rw.add_child(UI.hb(10, [art, t, UI.bold("✓" if got else "", 20, UI.GREEN)]))
	b.add_child(UI.m_card(rw))
	b.add_child(UI.btn("All division rewards", func(): _preview(d), "Small"))
	var tm = Timer.new(); tm.wait_time = 1.0; tm.autostart = true; f.node.add_child(tm)
	var last_un = {"n": un.size()}
	tm.timeout.connect(func():
		upd.call()
		if Rivals.st().unclaimed.size() != last_un.n and UI.modals.is_empty() and UI.cur_name == "rivals": UI.replace("rivals"))
	return {"node": f.node, "bg": "hub", "back": _back_or_play}
